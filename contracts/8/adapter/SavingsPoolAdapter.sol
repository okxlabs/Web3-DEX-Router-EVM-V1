// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/ISavings.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";

/**
 * @title SavingsPoolAdapter
 * @notice Adapter for Spark Savings Pool
 * @dev Adapter for Spark Savings Pool
 * 
 * External Methods Used:
 *   - deposit(uint256 assets, address to) -> void : Deposits assets into the Savings Pool
 *   - redeem(uint256 shares, address to, address from) -> void : Redeems shares from the Savings Pool
 * 
 * Supported Savings Protocols:
 *   - Spark Savings Pool
 * 
 */
contract SavingsPoolAdapter is IAdapter {

    // fromToken == Asset
    function sellBase(
        address to,
        address pool,
        bytes memory
    ) external override {
        address asset = ISavings(pool).asset();
        uint256 assets = IERC20(asset).balanceOf(address(this));
        SafeERC20.safeApprove(
            IERC20(asset),
            pool,
            assets
        );
        ISavings(pool).deposit(assets, to);
    }

    // fromToken == Savings Token
    function sellQuote(
        address to,
        address pool,
        bytes memory
    ) external override {
        uint256 shares = IERC20(pool).balanceOf(address(this));
        ISavings(pool).redeem(shares, to, address(this));
    }
}
