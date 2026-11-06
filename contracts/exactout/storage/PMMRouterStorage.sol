// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PMMRouterStorage {
    uint256[6] internal DEPRECATED_slots; // to take over 6 slots
    // pmm payer => pmm operator
    mapping(address => address) internal DEPRECATED_operator;
    mapping(bytes32 => uint256) internal DEPRECATED_orderRemaining;
    uint256 internal DEPRECATED_feeRateAndReceiver; // 2bytes feeRate + 0000... + 20bytes feeReceiver
    uint256[50] internal DEPRECATED__pmmRouterGap;
}
