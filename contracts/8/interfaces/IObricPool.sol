// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IObricPool {
    function xToken() external view returns (address);

    function yToken() external view returns (address);

    function swap(uint256 inputAmount, bool isXtoY) external;
}


