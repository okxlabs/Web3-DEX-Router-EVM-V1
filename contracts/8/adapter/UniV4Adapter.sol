// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IPoolManager.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {Currency} from "../types/Currency.sol";
import {BalanceDelta} from "../types/BalanceDelta.sol";
import {SafeCallback} from "../libraries/SafeCallback.sol";
import "../libraries/TransientStateLibrary.sol";
import {SafeCast} from "../libraries/SafeCast.sol";

/// @title UniV4Adapter for single hop swap
/// @notice Interacts with PoolManager to facilitate Uniswap V4 swaps
contract UniV4Adapter is IAdapter, SafeCallback {
    using SafeERC20 for IERC20;
    using SafeCast for *;
    using TransientStateLibrary for IPoolManager;

    address public immutable WETH;
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    uint160 internal constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 internal constant ORIGIN_PAYER =
        0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;

    error NotEnoughLiquidity(PoolId poolId);
    event Received(address, uint256);

    struct PathKey {
        Currency inputCurrency;
        Currency outputCurrency;
        uint24 fee;
        int24 tickSpacing;
    }

    constructor(address _poolManager, address _weth) SafeCallback(IPoolManager(_poolManager)) {
        WETH = _weth;
    }

    function _setupPathKey(bytes calldata moreInfo) internal pure returns (PathKey memory) {
        (address tokenIn, address tokenOut, uint24 fee, int24 tickSpacing) = abi.decode(moreInfo, (address, address, uint24, int24));
        PathKey memory pathkey = PathKey({
            inputCurrency: Currency.wrap(tokenIn),
            outputCurrency: Currency.wrap(tokenOut),
            fee: fee,
            tickSpacing: tickSpacing
        });
        return pathkey;
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
        _unlock(_setupPathKey(moreInfo), to, payerOrigin);
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
        _unlock(_setupPathKey(moreInfo), to, payerOrigin);
    }

    function _unlock(PathKey memory pathkey, address to, uint256 payerOrigin) internal {
        uint256 amountIn;
        if (Currency.unwrap(pathkey.inputCurrency) == address(0)) {
            amountIn = IERC20(WETH).balanceOf(address(this));
            IWETH(WETH).withdraw(amountIn);
        } else {
            amountIn = IERC20(Currency.unwrap(pathkey.inputCurrency)).balanceOf(address(this));
        }
        bytes memory unlockdata = abi.encode(
            pathkey, 
            amountIn, 
            to,
            payerOrigin
        );
        poolManager.unlock(unlockdata);
    }

    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Unauthorized unlockCallback");

        (PathKey memory pathKey, uint256 amountIn, address to, uint256 payerOrigin) = abi.decode(data, (PathKey, uint256, address, uint256));

        address _payerOrigin;
        if ((payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            _payerOrigin = address(uint160(uint256(payerOrigin) & ADDRESS_MASK));
        }

        (PoolKey memory poolKey, bool zeroForOne) = getPoolAndSwapDirection(pathKey, pathKey.inputCurrency); 

        uint256 settledAmount = _settle(pathKey.inputCurrency, amountIn);
        
        (uint128 actualAmountIn, uint128 amountOut) = _swap(poolKey, zeroForOne, -int256(settledAmount));
        
        require(amountOut > 0, "Amount must be positive");

        // Refund unused input tokens to payerOrigin
        int256 inputDelta = poolManager.currencyDelta(address(this), pathKey.inputCurrency);
        if (inputDelta > 0) {
            _take(pathKey.inputCurrency, _payerOrigin, uint256(inputDelta));
        }

        if (Currency.unwrap(pathKey.outputCurrency) == address(0)) { 
            _take(pathKey.outputCurrency, address(this), amountOut); 
            IWETH(WETH).deposit{value: amountOut}(); 
            SafeERC20.safeTransfer(IERC20(WETH), to, amountOut); 
        } else { 
            _take(pathKey.outputCurrency, to, amountOut); 
        }

        return "";
    }

    function getPoolAndSwapDirection(PathKey memory params, Currency currencyIn)
        internal
        pure
        returns (PoolKey memory poolKey, bool zeroForOne)
    {
        Currency currencyOut = params.outputCurrency;
        (Currency currency0, Currency currency1) =
            Currency.unwrap(currencyIn) < Currency.unwrap(currencyOut) ? (currencyIn, currencyOut) : (currencyOut, currencyIn);

        zeroForOne = Currency.unwrap(currencyIn) == Currency.unwrap(currency0);
        poolKey = PoolKey(currency0, currency1, params.fee, params.tickSpacing, IHooks(address(0)));
    }

    /// @notice if amountSpecified < 0, the swap is exactInput, otherwise exactOutput
    function _swap(PoolKey memory poolKey, bool zeroForOne, int256 amountSpecified)
        private
        returns (uint128 actualAmountIn, uint128 amountOut)
    {
        // for protection of exactOut swaps, sqrtPriceLimit is not exposed as a feature in this contract
        unchecked {
            BalanceDelta delta = poolManager.swap(
                poolKey,
                IPoolManager.SwapParams(
                    zeroForOne, amountSpecified, zeroForOne ? MIN_SQRT_PRICE + 1 : MAX_SQRT_PRICE - 1
                ),
                ""
            );

            if (zeroForOne) {
                actualAmountIn = (-delta.amount0()).toUint128();
                amountOut = delta.amount1().toUint128();
            } else {
                actualAmountIn = (-delta.amount1()).toUint128();
                amountOut = delta.amount0().toUint128();
            }
        }
    }

    /// @notice Pay and settle a currency to the PoolManager
    /// @dev For fee-on-transfer tokens, the actual settled amount may be less than the transfer amount
    /// @return paid The actual amount settled (after transfer fees if any)
    function _settle(Currency currency, uint256 amount) internal returns (uint256 paid) {
        if (amount == 0) return 0;
        poolManager.sync(currency);
        if (currency.isAddressZero()) {
            paid = poolManager.settle{value: amount}();
        } else {
            SafeERC20.safeTransfer(
                IERC20(Currency.unwrap(currency)),
                address(poolManager),
                amount
            );
            paid = poolManager.settle();
        }
    }

    /// @notice Take an amount of currency out of the PoolManager
    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        poolManager.take(currency, recipient, amount);
    }

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}