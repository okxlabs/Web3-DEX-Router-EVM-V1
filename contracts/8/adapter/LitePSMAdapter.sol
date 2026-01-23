// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IDssLitePsm.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";

/// @title LitePSMAdapter
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
contract LitePSMAdapter is IAdapter {
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public immutable to18ConversionFactor = 1 * 10 ** 12;
    
    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _executeSwap(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _executeSwap(to, pool, moreInfo);
    }

    function _executeSwap(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {
        address fromToken = abi.decode(moreInfo, (address));
        
        if (fromToken == USDC) {
            uint256 sellAmount = IERC20(USDC).balanceOf(address(this));
            SafeERC20.safeApprove(IERC20(USDC), pool, sellAmount);
            IDssLitePsm(pool).sellGem(
                to, 
                sellAmount
            );
        } else {
            uint256 buyAmount = IERC20(fromToken).balanceOf(address(this));
            SafeERC20.safeApprove(IERC20(fromToken), pool, buyAmount);
            IDssLitePsm(pool).buyGem(
                to, 
                buyAmount / to18ConversionFactor
            );
        }
    }
}