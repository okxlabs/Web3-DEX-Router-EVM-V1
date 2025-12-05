// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface ICurveStableSwap {
    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function coins(uint256 arg0) external view returns (address out);
    
    function balances(uint256 i) external view returns (uint256);
}

interface ICurveStableSwapMeta is ICurveStableSwap {
    function exchange_underlying(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint256);

    function get_dy_underlying(
        int128 i,
        int128 j,
        uint256 dx
    ) external view returns (uint256 dy);

    function underlying_coins(int128 arg0) external view returns (address out);
}