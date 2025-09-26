// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IOkoswapRouter {
    function factory() external view returns (address);
    function WETH() external view returns (address);

    /// @notice Swaps exact ETH for tokens along a specified path
    /// @dev Path must start with WETH, deducts 2% fee from input ETH
    /// @param amountOutMin Minimum amount of output tokens that must be received
    /// @param path Array of token addresses representing the swap route (must start with WETH)
    /// @param to Recipient address of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    function swapExactETHForTokens(
        uint256 amountOutMin, 
        address[] calldata path, 
        address to, 
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
        
    /// @notice Swaps exact tokens for ETH along a specified path
    /// @dev Path must end with WETH, deducts 2% fee from output ETH
    /// @param amountIn Exact amount of input tokens to swap
    /// @param amountOutMin Minimum amount of ETH that must be received
    /// @param path Array of token addresses representing the swap route (must end with WETH)
    /// @param to Recipient address of the ETH
    /// @param deadline Unix timestamp after which the transaction will revert
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    /// @notice Swaps exact tokens for tokens along a specified path
    /// @dev Path must start with token and end with token, deducts 2% fee from output tokens
    /// @param amountIn Exact amount of input tokens to swap
    /// @param amountOutMin Minimum amount of output tokens that must be received
    /// @param path Array of token addresses representing the swap route (must start with token and end with token)
    /// @param to Recipient address of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
