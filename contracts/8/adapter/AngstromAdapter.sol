// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;
import "../interfaces/IAdapter.sol";
import "../interfaces/IAngstromAdapter.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IPoolManager.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {Currency, equals, lessThan} from "../types/Currency.sol";
import {BalanceDelta} from "../types/BalanceDelta.sol";
import {SafeCallback} from "../libraries/SafeCallback.sol";
import "../libraries/TransientStateLibrary.sol";
/// @title AngstromAdapter
/// @notice Interacts with PoolManager to facilitate Uniswap V4 swaps
contract AngstromAdapter is IAdapter, IAngstromAdapter, SafeCallback {
    using SafeERC20 for IERC20;
    using TransientStateLibrary for IPoolManager;
    address public immutable WETH;
    uint160 internal constant MIN_SQRT_PRICE = 4295128739;
    uint160 internal constant MAX_SQRT_PRICE =
        1461446703485210103287273052203988822378723970342;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    error NotEnoughLiquidity(PoolId poolId);
    event Received(address, uint256);
    struct PathKey {
        // pool details to getId
        Currency inputCurrency;
        Currency intermediateCurrency;
        uint24 fee;
        int24 tickSpacing;
        // hook
        address hook;
        bytes hookData;
    }
    constructor(
        address _poolManager,
        address _weth
    ) SafeCallback(IPoolManager(_poolManager)) {
        WETH = _weth;
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
        _unlock(to, payerOrigin, moreInfo);
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
        _unlock(to, payerOrigin, moreInfo);
    }
    function _unlock(address to, uint256 payerOrigin, bytes calldata moreInfo) internal {
        poolManager.unlock(abi.encode(to, payerOrigin, moreInfo));
    }
    function _unlockCallback(
        bytes calldata data
    ) internal override returns (bytes memory) {
        (address to, uint256 payerOrigin, bytes memory moreInfo) = abi.decode(
            data,
            (address, uint256, bytes)
        );
        PathKey[] memory pathKeys = abi.decode(moreInfo, (PathKey[]));
        uint256 firstAmountIn;
        // get first amountIn
        if (pathKeys[0].inputCurrency.isAddressZero()) {
            firstAmountIn = IERC20(WETH).balanceOf(address(this));
            IWETH(WETH).withdraw(firstAmountIn);
        } else {
            firstAmountIn = pathKeys[0].inputCurrency.balanceOfSelf();
        }
        // swap
        (uint256 actualAmountIn, uint256 actualAmountOut) = _swap(pathKeys, firstAmountIn);
        require(actualAmountOut > 0, "Amount must be positive");
        require(actualAmountIn <= firstAmountIn, "AmountIn must be less than or equal to firstAmountIn");
        // transfer token from this contract to poolManager
        _settle(pathKeys[0].inputCurrency, actualAmountIn);
        // transfer token from poolManager to this contract
        Currency outputCurrency = pathKeys[pathKeys.length - 1].intermediateCurrency;
        if (outputCurrency.isAddressZero()) {
            poolManager.take(outputCurrency, address(this), actualAmountOut);
            IWETH(WETH).deposit{value: actualAmountOut}();
            SafeERC20.safeTransfer(IERC20(WETH), to, actualAmountOut);
        } else {
            poolManager.take(outputCurrency, to, actualAmountOut);
        }
        /// @notice Refund logic: if there is leftover fromToken, refund to payerOrigin
        /// @notice if inputCurrency is ETH, V4 will refund ETH to this contract
        if (firstAmountIn - actualAmountIn > 0) {
            address _payerOrigin = address(uint160(payerOrigin & ADDRESS_MASK));
            pathKeys[0].inputCurrency.transfer(_payerOrigin, firstAmountIn - actualAmountIn);
        }
        return "";
    }
    function getPoolAndSwapDirection(
        PathKey memory params
    ) internal pure returns (PoolKey memory poolKey, bool zeroForOne) {
        (Currency currency0, Currency currency1) = lessThan(params.inputCurrency, params.intermediateCurrency)
            ? (params.inputCurrency, params.intermediateCurrency)
            : (params.intermediateCurrency, params.inputCurrency);
        zeroForOne = equals(params.inputCurrency, currency0);
        poolKey = PoolKey(
            currency0,
            currency1,
            params.fee,
            params.tickSpacing,
            IHooks(params.hook)
        );
    }
    function _swap(
        PathKey[] memory pathKeys,
        uint256 firstAmountIn ///@notice amountIn for the first swap, if lp not enough, will return left amount
    ) internal returns (
        uint256 actualAmountIn, ///@notice amountIn for the first swap, actual amountIn, use this for settle amountIn
        uint256 actualAmountOut ///@notice amountOut for the last swap, actual amountOut, use this for take amountOut
    ) {
        BalanceDelta swapDelta;
        int256 amountIn = int256(firstAmountIn);
        for (uint256 i = 0; i < pathKeys.length; i++) {
            (PoolKey memory poolKey, bool zeroForOne) = getPoolAndSwapDirection(
                pathKeys[i]
            );

            IAngstromAdapter.Attestation[] memory bundle = abi.decode(
                pathKeys[i].hookData,
                (IAngstromAdapter.Attestation[])
            );
            // Select the correct attestation for the current block
            bytes memory hookData = _selectAttestation(bundle);

            amountIn = -amountIn;
            swapDelta = poolManager.swap(
                poolKey,
                IPoolManager.SwapParams({
                    zeroForOne: zeroForOne,
                    amountSpecified: amountIn, // int256
                    sqrtPriceLimitX96: zeroForOne
                        ? MIN_SQRT_PRICE + 1
                        : MAX_SQRT_PRICE - 1
                }),
                hookData // The attestation that unlocks the pool!
            );
            // Check that the pool was not illiquid.
            int128 amountSpecifiedActual = (zeroForOne == (amountIn < 0))
                ? swapDelta.amount0()
                : swapDelta.amount1();
            if (amountSpecifiedActual != amountIn)
                revert NotEnoughLiquidity(poolKey.toId());
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
    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        poolManager.sync(currency);
        if (currency.isAddressZero()) {
            poolManager.settle{value: amount}();
        } else {
            currency.transfer(address(poolManager), amount);
            poolManager.settle();
        }
    }
    /// @notice Selects the correct attestation for the current block
    /// @param bundle Array of attestations to choose from
    /// @return unlockData The attestation data for the current block
    function _selectAttestation(IAngstromAdapter.Attestation[] memory bundle)
        internal
        view
        returns (bytes memory unlockData)
    {
        uint256 currentBlock = block.number;
        for (uint256 i = 0; i < bundle.length; i++) {
            if (bundle[i].blockNumber == currentBlock) {
                return bundle[i].unlockData;
            }
        }
        // Revert if no attestation is found for the current block
        revert("MISSING_ATTESTATION_FOR_CURRENT_BLOCK");
    }
    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}