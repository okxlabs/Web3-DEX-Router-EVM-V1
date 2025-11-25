// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "../interfaces/IERC20.sol";

/// @title Liquidity Book Pair Interface (V2.1 & V2.2)
/// @notice Required interface of LBPair contract
interface ILBPair {
   function swap(bool swapForY, address to) external returns (bytes32 amountsOut);
   function getTokenX() external view returns (IERC20 tokenX);
}