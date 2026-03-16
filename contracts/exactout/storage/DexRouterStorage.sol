// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DexRouterStorage {
    // In the test scenario, we take it as a settable state and adjust it to a constant after it stabilizes
    address internal DEPRECATED_approveProxy;
    address internal DEPRECATED_wNativeRelayer;
    mapping(address => bool) internal DEPRECATED_priorityAddresses;

    uint256[19] internal DEPRECATED_dexRouterGap;

    address internal admin;
}
