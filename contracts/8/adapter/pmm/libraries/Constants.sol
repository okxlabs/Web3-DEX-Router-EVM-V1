// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @dev Marker for the calldata word at offset -64.
uint256 constant DEX_ROUTER_CALLER_MARKER =
    0x3ca20afc2ddd0000000000000000000000000000000000000000000000000000;

/// @dev Marker mask.
uint256 constant MARKER_MASK =
    0xffffffffffff0000000000000000000000000000000000000000000000000000;

/// @dev Marker for the calldata word at offset -32.
uint256 constant ORIGIN_PAYER =
    0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;

/// @dev Address mask.
uint256 constant _ADDRESS_MASK =
    0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
