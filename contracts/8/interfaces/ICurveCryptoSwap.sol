// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface ICurveCryptoSwap {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    ) external returns (uint256);

    function exchange_received(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        address receiver
    ) external returns (uint256);
    
    function balances(uint256 i) external view returns (uint256);
}