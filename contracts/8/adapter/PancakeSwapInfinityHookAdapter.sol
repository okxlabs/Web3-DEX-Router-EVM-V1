// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";

// PancakeSwap Infinity specific imports
import {IVault} from "../interfaces/PancakeSwapInfinity/IVault.sol";
import {ICLPoolManager} from "../interfaces/PancakeSwapInfinity/ICLPoolManager.sol";
import {IBinPoolManager} from "../interfaces/PancakeSwapInfinity/IBinPoolManager.sol";
import {PoolKey} from "../types/PancakeSwapInfinity/PoolKey.sol";
import {PoolId} from "../types/PancakeSwapInfinity/PoolId.sol";
import {Currency} from "../types/Currency.sol";
import {BalanceDelta} from "../types/BalanceDelta.sol";
import {IHooks} from "../interfaces/PancakeSwapInfinity/IHooks.sol";
import {IPoolManager} from "../interfaces/PancakeSwapInfinity/IPoolManager.sol";
import {SafeCallback} from "../libraries/PancakeSwapInfinity/SafeCallback.sol";
import {SafeCast} from "../libraries/SafeCast.sol";

/// @title PancakeSwap Infinity Adapter for multi-hop swaps with or without hook
/// @notice Interacts with Infinity Vault and both CL/Bin PoolManagers to facilitate swaps
/// @dev Note: Unlike UniV4Adapter, this adapter doesn't import TransientStateLibrary
///      because PancakeSwap Infinity provides transient state access through:
///      - vault.currencyDelta(settler, currency) for balance queries
///      - SettlementGuard.getCurrencyDelta() for internal state management
///      If advanced transient state operations are needed in the future,
///      consider integrating SettlementGuard library functions directly
contract PancakeSwapInfinityHookAdapter is IAdapter, SafeCallback {
    using SafeERC20 for IERC20;
    using SafeCast for *;

    address public immutable WNATIVE;
    address public immutable clPoolManager;
    address public immutable binPoolManager;
    
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    error NotEnoughLiquidity(PoolId poolId);
    error UnsupportedPoolManager(address poolManager);
    event Received(address, uint256);

    struct PathKey {
        Currency inputCurrency;
        Currency outputCurrency;
        address poolManager;
        uint24 fee;
        uint256 poolParams; // For CL: tickSpacing (int24), For Bin: binStep (uint16)
        // hook
        address hook;
        bytes hookData;
    }

    constructor(IVault _vault, address _wnative, address _clPoolManager, address _binPoolManager) SafeCallback(_vault) {
        WNATIVE = _wnative;
        clPoolManager = _clPoolManager;
        binPoolManager = _binPoolManager;
    }

    function sellBase(
        address to,
        address /* pool */,
        bytes calldata moreInfo
    ) external override {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _lock(to, payerOrigin, moreInfo);
    }

    function sellQuote(
        address to,
        address /* pool */,
        bytes calldata moreInfo
    ) external override {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _lock(to, payerOrigin, moreInfo);
    }

    function _lock(address to, uint256 payerOrigin, bytes calldata moreInfo) internal {
        bytes memory lockData = abi.encode(
            to,
            payerOrigin,
            moreInfo
        );
        vault.lock(lockData);
    }

    function _lockAcquired(bytes calldata data) internal override returns (bytes memory) {
        require(msg.sender == address(vault), "Unauthorized lockAcquired");

        (address to, uint256 payerOrigin, bytes memory moreInfo) = abi.decode(data, (address, uint256, bytes));
        PathKey[] memory pathKeys = abi.decode(moreInfo, (PathKey[]));

        uint256 firstAmountIn;

        // get first amountIn
        if (pathKeys[0].inputCurrency.isAddressZero()) {
            firstAmountIn = IERC20(WNATIVE).balanceOf(address(this));
            IWETH(WNATIVE).withdraw(firstAmountIn);
        } else {
            firstAmountIn = pathKeys[0].inputCurrency.balanceOfSelf();
        }

        // swap
        (uint256 actualAmountIn, uint256 actualAmountOut) = _swap(pathKeys, firstAmountIn);
        require(actualAmountOut > 0, "Amount must be positive");
        require(actualAmountIn <= firstAmountIn, "AmountIn must be less than or equal to firstAmountIn");
        
        // transfer token from this contract to vault
        _settle(pathKeys[0].inputCurrency, actualAmountIn);

        // transfer token from vault to this contract
        Currency outputCurrency = pathKeys[pathKeys.length - 1].outputCurrency;
        if (outputCurrency.isAddressZero()) { 
            vault.take(outputCurrency, address(this), actualAmountOut);
            IWETH(WNATIVE).deposit{value: actualAmountOut}(); 
            SafeERC20.safeTransfer(IERC20(WNATIVE), to, actualAmountOut); 
        } else {
            vault.take(outputCurrency, to, actualAmountOut);
        }

        /// @notice Refund logic: if there is leftover fromToken, refund to payerOrigin
        /// @notice if inputCurrency is ETH, Pancake Infinity will refund ETH to this contract
        if (firstAmountIn - actualAmountIn > 0) {
            address _payerOrigin = address(uint160(payerOrigin & ADDRESS_MASK));
            pathKeys[0].inputCurrency.transfer(_payerOrigin, firstAmountIn - actualAmountIn);
        }

        return "";
    }

    function getPoolAndSwapDirection(PathKey memory params)
        internal
        view
        returns (PoolKey memory poolKey, bool zeroForOne)
    {
        Currency currencyIn = params.inputCurrency;
        Currency currencyOut = params.outputCurrency;
        (Currency currency0, Currency currency1) =
            Currency.unwrap(currencyIn) < Currency.unwrap(currencyOut) ? (currencyIn, currencyOut) : (currencyOut, currencyIn);

        zeroForOne = Currency.unwrap(currencyIn) == Currency.unwrap(currency0);
        
        // Create the parameters bytes32 based on pool manager type and hook permissions
        bytes32 parameters = _encodePoolParameters(params);
        
        poolKey = PoolKey({
            currency0: currency0, 
            currency1: currency1, 
            hooks: IHooks(params.hook), 
            poolManager: IPoolManager(params.poolManager),
            fee: params.fee, 
            parameters: parameters
        });
    }

    /// @notice Encode pool parameters based on pool manager type
    ///      According to PancakeSwap Infinity spec:
    ///      - bytes32 parameters = hookPermissions(16 bits) + AMM-specific(16/24 bits)
    ///      
    ///      - CL pools: hookPermissions(16 bits) + tickSpacing(24 bits)
    ///         - example: 0x00000000000000000000000000000000000000000000000000000000000a00c2,
    ///         - Hook permission: 0x00c2 → 0000 0000 1100 0010 (in bits), support hook1,hook6,hook7
    ///         - Tick spacing: 0x00000a → decimal 10
    ///      - Bin pools: hookPermissions(16 bits) + binStep(16 bits)
    /// @param params The PathKey containing hook address and pool parameters
    /// @return parameters Encoded bytes32 parameters for PoolKey
    function _encodePoolParameters(PathKey memory params) private view returns (bytes32 parameters) {
        // Get hook permissions from the hook contract if hook address is not zero
        uint16 hookPermissions = 0x0000;
        if (params.hook != address(0)) {
            hookPermissions = IHooks(params.hook).getHooksRegistrationBitmap();
        }
        
        if (params.poolManager == clPoolManager) {
            // CL pools: hookPermissions(16 bits) + tickSpacing(24 bits)
            // Shift tickSpacing to bits [16-39] and OR with hookPermissions in bits [0-15]
            int24 tickSpacing = int24(int256(params.poolParams));
            uint256 encoded = (uint256(uint24(tickSpacing)) << 16) | uint256(hookPermissions);
            parameters = bytes32(encoded);
            
        } else if (params.poolManager == binPoolManager) {
            // Bin pools: hookPermissions(16 bits) + binStep(16 bits)
            // Shift binStep to bits [16-31] and OR with hookPermissions in bits [0-15]
            uint16 binStep = uint16(params.poolParams);
            uint256 encoded = (uint256(binStep) << 16) | uint256(hookPermissions);
            parameters = bytes32(encoded);
            
        } else {
            revert UnsupportedPoolManager(params.poolManager);
        }
    }

    function _swap(
        PathKey[] memory pathKeys,
        uint256 firstAmountIn
    ) internal returns (
        uint256 actualAmountIn,
        uint256 actualAmountOut
    ) {
       BalanceDelta swapDelta;
       address poolManagerAddr;
       int256 amountIn = int256(firstAmountIn);

       for (uint256 i = 0; i < pathKeys.length; i++) {
            (PoolKey memory poolKey, bool zeroForOne) = getPoolAndSwapDirection(
                pathKeys[i]
            );
            amountIn = -amountIn;
            poolManagerAddr = address(poolKey.poolManager);

            if (poolManagerAddr == clPoolManager) {
                swapDelta = ICLPoolManager(poolManagerAddr).swap(
                    poolKey,
                    ICLPoolManager.SwapParams({
                        zeroForOne: zeroForOne,
                        amountSpecified: amountIn,
                        sqrtPriceLimitX96: zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1
                    }),
                    pathKeys[i].hookData
                );
            } else if (poolManagerAddr == binPoolManager) {
                swapDelta = IBinPoolManager(poolManagerAddr).swap(
                    poolKey,
                    zeroForOne, // x for y
                    int128(amountIn),
                    pathKeys[i].hookData
                );
            } else {
                revert UnsupportedPoolManager(poolManagerAddr);
            }

            // Check that the pool was not illiquid.
            int128 amountSpecifiedActual = (zeroForOne == (amountIn < 0))
                ? swapDelta.amount0()
                : swapDelta.amount1();
            // if (amountSpecifiedActual != amountIn)
            //     revert NotEnoughLiquidity(poolKey.toId());
            // update next amountIn for next swap using the amountOut of the current swap
            amountIn = zeroForOne
                ? int256(swapDelta.amount1())
                : int256(swapDelta.amount0());
            

            if (i == 0) { // get actual amountIn for the first swap
                actualAmountIn = zeroForOne ? uint256(-int256(swapDelta.amount0())) : uint256(-int256(swapDelta.amount1()));
            }

            if (i == pathKeys.length - 1) { // get actual amountOut for the last swap
                actualAmountOut = uint256(amountIn);
            }
       }
    }

    /// @notice Pay and settle a currency to the Vault
    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        vault.sync(currency);
        if (currency.isAddressZero()) {
            vault.settle{value: amount}();
        } else {
            SafeERC20.safeTransfer(
                IERC20(Currency.unwrap(currency)),
                address(vault),
                amount
            );
            vault.settle();
        }
    }

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
} 