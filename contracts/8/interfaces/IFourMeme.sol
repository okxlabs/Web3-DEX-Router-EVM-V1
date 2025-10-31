/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface ITokenManager2 {
    struct TokenInfo {
        address base;
        address quote;
        uint256 template;
        uint256 totalSupply;
        uint256 maxOffers;
        uint256 maxRaising;
        uint256 launchTime;
        uint256 offers;
        uint256 funds;
        uint256 lastPrice;
        uint256 K;
        uint256 T;
        uint256 statu;
    }

    function buyToken(
        bytes memory args,
        uint256 time,
        bytes memory signature
    ) external payable;

    function _tokenInfos(address token) external view returns (TokenInfo memory tokenInfo);

    function buyTokenAMAP(
        address token,
        address to, 
        uint256 funds, 
        uint256 minAmount
    ) external payable;

    function sellToken(
        address token, 
        uint256 amount
    ) external;

    function sellToken(
        uint256 origin, //The platform from which the request is sent. Pass 0 if not applicable.
        address token, //The address of the token to be sold.
        address from, //The address of the token owner(tx.orgin == from).
        uint256 amount, //The amount of tokens to be sold.
        uint256 minFunds, //The minimum amount of funds to be received after the sale.
        uint256 feeRate, //The router’s fee rate. 100 means 1%, and 10 means 0.1%. (MAX 5%)
        address feeRecipient//The address that will receive the fee.
    ) external;
}

interface ITokenManagerHelper3 {
    /// @notice Sell tokens for ETH
    /// @dev If the user wants to sell tokens for BNB through a third-party router, the original sender of the transaction must be the token owner.
    /// This method is only applicable for ERC20/ERC20 trading pairs (quote token is not address(0)). It is not supported for BNB trading pairs.
    /// The trading fee will be collected in the quote token (ERC20) instead of BNB.
    function sellForEth(
        uint256 origin, // The platform from which the request is sent. Pass 0 if not applicable.
        address token, // The address of the token to sell
        address from, // The address of the token owner (tx.origin must equal from)
        uint256 amount, // The amount of tokens to sell
        uint256 minFunds, // The minimum amount of BNB to receive
        uint256 feeRate, // The fee rate for the transaction. 100 means 1%, 10 means 0.1%. (MAX 5%)
        address feeRecipient // The address that will receive the fee (in quote token)
    ) external;
}