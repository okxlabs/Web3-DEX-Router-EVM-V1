// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IEkubo.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";

using PoolKeyLibrary for PoolKey;

contract EkuboAdapter is IAdapter {
    address public immutable WETH;
    address public immutable EKUBO_CORE;

    address internal constant ETH = address(0);
    uint96 constant MIN_SQRT_RATIO_RAW = 4611797791050542631 + 1;
    uint96 constant MAX_SQRT_RATIO_RAW = 79227682466138141934206691491 - 1;
    uint256 internal constant ORIGIN_PAYER =
        0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    struct SwapParams {
        address to;
        PoolKey poolKey;
        int128 amount;
        bool isToken1;
        uint96 sqrtRatioLimit;
        uint256 skipAhead;
        uint128 _token0Debts;
        uint128 _token1Debts;
    }

    SwapParams private _swapParams;

    constructor(address payable weth, address ekuboCore) {
        WETH = weth;
        EKUBO_CORE = ekuboCore;
    }

    function _ekuboSwap(
        address to,
        address,
        bytes memory moreInfo,
        uint256 payerOrigin
    ) private {
        (PoolKey memory poolKey, bool isToken1) = abi.decode(
            moreInfo,
            (PoolKey, bool)
        );

        address fromToken = isToken1 ? poolKey.token1 : poolKey.token0;

        uint256 inputBalance;
        if (fromToken == ETH) {
            inputBalance = IERC20(WETH).balanceOf(address(this));
        } else {
            inputBalance = IERC20(fromToken).balanceOf(address(this));
        }

        require(inputBalance > 0, "No tokens to swap");
        int128 swapAmount = int128(uint128(inputBalance));

        uint96 sqrtRatioLimit = isPriceIncreasing(swapAmount, isToken1)
            ? MAX_SQRT_RATIO_RAW
            : MIN_SQRT_RATIO_RAW;

        _swapParams = SwapParams({
            to: to,
            poolKey: poolKey,
            amount: swapAmount,
            isToken1: isToken1,
            sqrtRatioLimit: sqrtRatioLimit,
            skipAhead: 0,
            _token0Debts: 0,
            _token1Debts: 0
        });

        // lock() -> locked() callback
        IEkuboCore(EKUBO_CORE).lock();

        delete _swapParams;

        // Return back excess fromTokens
        address _payerOrigin;
        if ((payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            _payerOrigin = address(uint160(uint256(payerOrigin) & ADDRESS_MASK));
        }
        if (_payerOrigin != address(0)) {
            if (fromToken == ETH && address(this).balance > 0) {
                (bool success, ) = _payerOrigin.call{
                    value: address(this).balance
                }("");
                require(success, "Transfer to payerOrigin failed");
            } else if (fromToken != ETH) {
                uint256 leftBalance = IERC20(fromToken).balanceOf(
                    address(this)
                );
                if (leftBalance > 0) {
                    SafeERC20.safeTransfer(IERC20(fromToken), _payerOrigin, leftBalance);
                }
            }
        }
    }

    function locked(uint256 id) external returns (bytes memory) {
        require(msg.sender == EKUBO_CORE, "Only Ekubo Core can call");

        SwapParams memory params = _swapParams;

        (int128 delta0, int128 delta1) = IEkuboCore(EKUBO_CORE).swap_611415377(
            params.poolKey,
            params.amount,
            params.isToken1,
            params.sqrtRatioLimit,
            params.skipAhead
        );

        address fromToken = params.isToken1
            ? params.poolKey.token1
            : params.poolKey.token0;
        // Handle debt
        // if either token is ETH, it must be token0, as tokens are sorted when pool initializing
        if (delta0 > 0) {
            if (fromToken == ETH) {
                // Withdraw all WETH to ETH, but only transfer the exact debt amount
                uint256 wethBalance = IERC20(WETH).balanceOf(address(this));
                IWETH(WETH).withdraw(wethBalance);
                
                // Only send the exact debt amount, not the full balance
                uint256 debtAmount = uint128(delta0);
                (bool success, ) = EKUBO_CORE.call{value: debtAmount}("");
                require(success, "Transfer ETH debt to Ekubo Core failed");
                
                // Remaining ETH will be refunded to user in the refund logic
            } else {
                // Only record debt for ERC20 tokens that will trigger payCallback
                _swapParams._token0Debts = uint128(delta0);
                IEkuboCore(EKUBO_CORE).pay(params.poolKey.token0);
            }
        }
        if (delta1 > 0) {
            _swapParams._token1Debts = uint128(delta1);
            IEkuboCore(EKUBO_CORE).pay(params.poolKey.token1);
        }

        // Withdraw to tokens
        address outputToken = params.isToken1
            ? params.poolKey.token0
            : params.poolKey.token1;
        uint128 outputAmount = uint128(params.isToken1 ? -delta0 : -delta1);

        if (outputAmount > 0) {
            if (outputToken == ETH) {
                IEkuboCore(EKUBO_CORE).withdraw(
                    outputToken,
                    address(this),
                    outputAmount
                );
                IWETH(WETH).deposit{value: outputAmount}();
                SafeERC20.safeTransfer(IERC20(WETH), params.to, outputAmount);
            } else {
                IEkuboCore(EKUBO_CORE).withdraw(
                    outputToken,
                    params.to,
                    outputAmount
                );
            }
        }

        return "";
    }

    /// @notice Pay callback - Triggered by Core pay()
    function payCallback(uint256 /* id */, address token) external {
        require(msg.sender == EKUBO_CORE, "Only Ekubo Core can call");

        // Determine which debt to pay based on token address
        uint256 debtAmount;
        if (token == _swapParams.poolKey.token0) {
            debtAmount = _swapParams._token0Debts;
            _swapParams._token0Debts = 0; // Clear the debt
        } else if (token == _swapParams.poolKey.token1) {
            debtAmount = _swapParams._token1Debts;
            _swapParams._token1Debts = 0; // Clear the debt
        } else {
            revert("Unknown token for debt payment");
        }
        
        require(debtAmount > 0, "No debt recorded for this token");
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= debtAmount, "Insufficient balance to pay debt");
        
        // Transfer only the exact debt amount
        SafeERC20.safeTransfer(IERC20(token), EKUBO_CORE, debtAmount);
    }

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _ekuboSwap(to, pool, moreInfo, payerOrigin);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _ekuboSwap(to, pool, moreInfo, payerOrigin);
    }

    function isPriceIncreasing(
        int128 amount,
        bool isToken1
    ) private pure returns (bool increasing) {
        assembly ("memory-safe") {
            increasing := xor(isToken1, slt(amount, 0))
        }
    }

    receive() external payable {}
}