/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IVenusToken {
    function mint() external payable;
    function mint(uint256 mintAmount) external returns (uint);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function underlying() external view returns (address);
    function isVToken() external view returns (bool);
}
