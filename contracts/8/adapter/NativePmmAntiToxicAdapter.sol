// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/INativeRfqPoolV3.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";
import "../libraries/CallerAuth.sol";
import "../libraries/Constants.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title NativePmmAntiToxicAdapter — RFQ/PMM adapter with signed caller/beneficiary binding.
contract NativePmmAntiToxicAdapter is IAdapter, NativeAuth, ReentrancyGuard {
    address public immutable WETH;
    address public immutable NATIVE_ROUTER;

    struct MoreInfo {
        INativeRfqPoolV3.RFQTQuote quote;
        address beneficiary;
        address[] allowedCallers;
        uint256 nonce;
        bytes authSig;
    }

    constructor(address weth, address nativeRouter, address authSigner) NativeAuth(authSigner) {
        require(weth != address(0) && nativeRouter != address(0), "zero addr");
        WETH = weth;
        NATIVE_ROUTER = nativeRouter;
    }

    /// @inheritdoc IAdapter
    function sellBase(
        address to,
        address, /* pool */
        bytes memory moreInfo
    ) external override nonReentrant {
        _nativePmmSwap(to, moreInfo);
    }

    /// @inheritdoc IAdapter
    function sellQuote(
        address to,
        address, /* pool */
        bytes memory moreInfo
    ) external override nonReentrant {
        _nativePmmSwap(to, moreInfo);
    }

    // =========================== Core flow ===========================

    function _nativePmmSwap(address to, bytes memory moreInfo) internal {
        MoreInfo memory info = abi.decode(moreInfo, (MoreInfo));
        INativeRfqPoolV3.RFQTQuote memory quote = info.quote;

        require(quote.recipient == address(this), "bad recipient");
        _verifyNativeAuth(
            abi.encode(quote),
            info.beneficiary,
            info.allowedCallers,
            info.nonce,
            info.authSig
        );

        address dexRouterCaller = _extractDexRouterCaller();
        require(
            dexRouterCaller != address(0) && info.beneficiary == dexRouterCaller,
            "beneficiary mismatch"
        );

        address refundTo = _extractRefundTo();
        require(refundTo != address(0), "invalid refundTo");

        _executeTrade(to, quote, refundTo);
    }

    function _executeTrade(
        address to,
        INativeRfqPoolV3.RFQTQuote memory quote,
        address refundReceiver
    ) internal {
        (uint256 value, uint256 actualAmountIn) = _prepareInput(quote);

        INativeRfqPoolV3 rfqPool = INativeRfqPoolV3(payable(NATIVE_ROUTER));
        rfqPool.tradeRFQT{value: value}(quote, actualAmountIn, 0);

        address outputToken = quote.buyerToken;
        if (outputToken == address(0)) {
            uint256 ethBalance = address(this).balance;
            if (ethBalance > 0) {
                IWETH(WETH).deposit{value: ethBalance}();
            }
            outputToken = WETH;
        }
        _transferAssetBalance(outputToken, to);
        _transferAssetBalance(quote.sellerToken, refundReceiver);
    }

    function _prepareInput(INativeRfqPoolV3.RFQTQuote memory quote)
        internal
        returns (uint256 value, uint256 actualAmountIn)
    {
        if (quote.sellerToken == address(0)) {
            value = IERC20(WETH).balanceOf(address(this));
            IWETH(WETH).withdraw(value);
            actualAmountIn = value;
        } else {
            actualAmountIn = IERC20(quote.sellerToken).balanceOf(address(this));
        }

        if (actualAmountIn >= (quote.sellerTokenAmount * 110) / 100) {
            actualAmountIn = (quote.sellerTokenAmount * 109) / 100;
        }

        if (quote.sellerToken == address(0)) {
            value = actualAmountIn;
        } else {
            SafeERC20.safeApprove(IERC20(quote.sellerToken), NATIVE_ROUTER, actualAmountIn);
        }
    }

    function _transferAssetBalance(address asset, address recipient) private {
        if (asset == address(0)) {
            uint256 balance = address(this).balance;
            if (balance > 0) {
                (bool success, ) = payable(recipient).call{value: balance}("");
                require(success, "refund ETH failed");
            }
        } else {
            IERC20 erc20 = IERC20(asset);
            uint256 balance = erc20.balanceOf(address(this));
            if (balance > 0) {
                SafeERC20.safeTransfer(erc20, recipient, balance);
            }
        }
    }

    function _extractRefundTo() private pure returns (address refundTo) {
        assembly {
            let word := calldataload(sub(calldatasize(), 32))
            if eq(and(word, MARKER_MASK), ORIGIN_PAYER) {
                refundTo := and(word, _ADDRESS_MASK)
            }
        }
    }

    receive() external payable {}
}
