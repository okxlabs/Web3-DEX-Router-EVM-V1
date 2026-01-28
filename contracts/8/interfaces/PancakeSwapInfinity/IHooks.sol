//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for pool hooks
interface IHooks {
    function getHooksRegistrationBitmap() external view returns (uint16);
} 