// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title Liquidity Book Pair Interface
/// @author Trader Joe
/// @notice Required interface of LBPair contract
interface ILBPair {
    function swap(bool sentTokenY, address to) external returns (uint256 amountXOut, uint256 amountYOut);
    function tokenX() external view returns (address);
}
