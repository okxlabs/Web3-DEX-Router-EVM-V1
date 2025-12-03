// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IPoolManager.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {Currency, equals, lessThan} from "../types/Currency.sol";
import {BalanceDelta} from "../types/BalanceDelta.sol";
import {SafeCallback} from "../libraries/SafeCallback.sol";
import "../libraries/TransientStateLibrary.sol";
/// @title UniV4HookAdapter
/// @notice Interacts with PoolManager to facilitate Uniswap V4 swaps
contract UniV4HookAdapter is IAdapter, SafeCallback {
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

        uint256 settledAmount = _settle(pathKeys[0].inputCurrency, firstAmountIn);

        // swap with the actual settled amount
        (uint256 actualAmountIn, uint256 actualAmountOut) = _swap(pathKeys, settledAmount);
        require(actualAmountOut > 0, "Amount must be positive");
        require(actualAmountIn <= settledAmount, "AmountIn must be less than or equal to settledAmount");

        // Refund unused input tokens to payerOrigin
        address _payerOrigin = address(uint160(payerOrigin & ADDRESS_MASK));
        int256 inputDelta = poolManager.currencyDelta(address(this), pathKeys[0].inputCurrency);
        if (inputDelta > 0) {
            poolManager.take(pathKeys[0].inputCurrency, _payerOrigin, uint256(inputDelta));
        }

        // transfer token from poolManager to this contract
        Currency outputCurrency = pathKeys[pathKeys.length - 1].intermediateCurrency;
        if (outputCurrency.isAddressZero()) {
            poolManager.take(outputCurrency, address(this), actualAmountOut);
            IWETH(WETH).deposit{value: actualAmountOut}();
            SafeERC20.safeTransfer(IERC20(WETH), to, actualAmountOut);
        } else {
            poolManager.take(outputCurrency, to, actualAmountOut);
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
                pathKeys[i].hookData
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

    function _settle(Currency currency, uint256 amount) internal returns (uint256 paid) {
        if (amount == 0) return 0;
        poolManager.sync(currency);
        if (currency.isAddressZero()) {
            paid = poolManager.settle{value: amount}();
        } else {
            currency.transfer(address(poolManager), amount);
            paid = poolManager.settle();
        }
    }

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}
