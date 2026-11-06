// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IWNativeRelayer {
    function withdraw(uint256 _amount) external;
}
