// SPDX-License-Identifier: MIT
// solhint-disable
pragma solidity ^0.8.0;

import {IAdapter} from "../../interfaces/IAdapter.sol";
import {IERC20} from "../../interfaces/IERC20.sol";
import {IERC4626} from "../../interfaces/IERC4626.sol";
import {SafeERC20} from "../../libraries/SafeERC20.sol";
import {RefundLib} from "../../libraries/Adapters.sol";

/**
 * @title UniversalERC4626Adapter
 * @notice Universal adapter for ERC4626 vaults (asset <-> share)
 * @dev Converts the full balance held by this adapter, and sends output to `to`.
 *
 * External Methods Used:
 *   - IERC4626(pool).asset() -> address : Returns the underlying asset token of the vault
 *   - IERC4626(pool).deposit(uint256 assets, address receiver) -> uint256 shares : Deposits assets and mints shares to receiver
 *   - IERC4626(pool).redeem(uint256 shares, address receiver, address owner) -> uint256 assets : Burns shares and sends assets to receiver
 *   - IERC20(token).balanceOf(address account) -> uint256 : Reads this adapter's token balance
 *   - IERC20(token).approve(address spender, uint256 amount) -> bool : Allows vault to pull assets (used via SafeERC20.safeApprove)
 *
 * Supported Vault Protocols:
 *   - Any ERC4626-compliant vault (EIP-4626)
 *
 * moreInfo encoding:
 *   abi.encode(address tokenIn, address tokenOut)
 *
 * Usage Examples:
 * ```solidity
 * // asset -> shares
 * adapter.sellBase(to, vault, "");
 *
 * // shares -> asset
 * adapter.sellQuote(to, vault, "");
 * ```
 */
contract UniversalERC4626Adapter is IAdapter {

    /// @notice throw error when amount is zero
    error InvalidAmount();
    /// @notice throw error when tokenIn/tokenOut is not an ERC4626 asset/share pair
    error InvalidTokenPair();

    // sellBase: token0 -> token1 (asset -> share)
    function sellBase(
        address to,
        address pool,
        bytes memory
    ) external override {
        address asset = IERC4626(pool).asset();
        uint256 amountIn = IERC20(asset).balanceOf(address(this));
        if (amountIn == 0) revert InvalidAmount();
        SafeERC20.safeApprove(
            IERC20(asset),
            pool,
            amountIn
        );
        IERC4626(pool).deposit(amountIn, to);
        _refund(asset);
    }

    // sellQuote: token1 -> token0 (share -> asset)
    function sellQuote(
        address to,
        address pool,
        bytes memory 
    ) external override {
        address asset = IERC4626(pool).asset();
        uint256 amountIn = IERC20(pool).balanceOf(address(this));
        if (amountIn == 0) revert InvalidAmount();
        IERC4626(pool).redeem(amountIn, to, address(this));
        _refund(asset);
    }

    function _refund(address token) internal {
        address payerOrigin = RefundLib.getPayerOrigin();
        if (payerOrigin == address(0)) return;

        uint256 dust = IERC20(token).balanceOf(address(this));
        if (dust > 0) {
            SafeERC20.safeTransfer(IERC20(token), payerOrigin, dust);
        }
    }
}
