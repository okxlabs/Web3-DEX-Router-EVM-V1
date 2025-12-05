// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface INativeRfqPool {
    struct WidgetFee {
        address signer;
        address feeRecipient;
        uint256 feeRate;
    }
    /// @notice Used for intra-chain RFQ-T trades.
    struct RFQTQuote {
        address pool;
        address signer;
        /// @notice The recipient of the buyerToken at the end of the trade.
        address recipient;
        /**
         * @notice The account "effectively" making the trade (ultimately receiving the funds).
         * This is commonly used by aggregators, where a proxy contract (the 'trader')
         * receives the buyerToken, and the effective trader is the user initiating the call.
         *
         * This field DOES NOT influence movement of funds. However, it is used to check against
         * quote replay.
         */
        // address effectiveTrader;
        /// @notice The token that the trader sells.
        address sellerToken;
        /// @notice The token that the trader buys.
        address buyerToken;
        /**
         * @notice The amount of sellerToken sold in this trade. The exchange rate
         * is going to be preserved as the buyerTokenAmount / sellerTokenAmount ratio.
         *
         * Most commonly, effectiveSellerTokenAmount will == sellerTokenAmount.
         */
        uint256 effectiveSellerTokenAmount;
        /// @notice The max amount of sellerToken sold.
        uint256 sellerTokenAmount;
        /// @notice The amount of buyerToken bought when sellerTokenAmount is sold.
        uint256 buyerTokenAmount;
        /// @notice The Unix timestamp (in seconds) when the quote expires.
        /// @dev This gets checked against block.timestamp.
        uint256 deadlineTimestamp;
        /// @notice The nonce used by this effectiveTrader. Nonces are used to protect against replay.
        uint256 nonce;
        /// @notice Unique identifier for the quote.
        /// @dev Generated off-chain via a distributed UUID generator.
        bytes16 quoteId;
        /// @dev  false if this quote is for the 1st hop of a multi-hop or a single-hop, in which case msg.sender is the payer.
        ///       true if this quote is for 2nd or later hop of a multi-hop, in which case router is the payer.
        bool multiHop;
        /// @notice Signature provided by the market maker (EIP-191).
        bytes signature;
        WidgetFee widgetFee;
        bytes widgetFeeSignature;
        /// @notice not used for RFQ flow, only for external swaps
        bytes externalSwapCalldata;
        /// @notice not used for RFQ flow, only for external swaps for slippage check
        uint amountOutMinimum;
    }

    function tradeRFQT(RFQTQuote memory quote) external payable;

    event SignerUpdated(address signer, bool value);
    event OwnerSet(address owner);
    event TreasurySet(address treasury);
    event PostTradeCallbackSet(bool value);
    event PauseSet(bool value);
    event RfqTrade(
        address recipient,
        address sellerToken,
        address buyerToken,
        uint256 sellerTokenAmount,
        uint256 buyerTokenAmount,
        bytes16 quoteId,
        address signer
    );

    error InvalidNewImplementation();
    error CallerNotFactory();
    error CallerNotRouter();
    error CallerNotOwner();
    error CallerNotPendingOwner();
    error ZeroOrEmptyInput();
    error TradePaused();
    error NonceUsed();
    error InvalidSigner();
    error InvalidSignature();
    error Overflow();
}
