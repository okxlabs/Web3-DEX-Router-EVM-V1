// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title TempStorage
/// @notice Library for managing temp storage using unique storage slots to avoid conflicts.
/// TODO: This library can be deleted when we have the transient keyword support in solidity.
library TempStorage {
    // Unique storage slots to avoid conflicts with other contract variables
    // keccak256("okx.unxswap.v3.router.amountConsumed");
    bytes32 private constant AMOUNT_CONSUMED_SLOT = 0x9ebcdcbd037b2a78528ae932be03ee202a81ff09aa80f303f792bd7e853f9b29;
    // keccak256("okx.unxswap.v3.router.ethAmount");
    bytes32 private constant ETH_AMOUNT_SLOT = 0xc7dba04ccda871fadc75891b098b16a68727089cdcf4bb23a18da603570f740d;

    /// @notice Sets the amountConsumed value in a unique storage slot
    /// @param value The value to set
    function setAmountConsumed(uint256 value) internal {
        assembly {
            sstore(AMOUNT_CONSUMED_SLOT, value)
        }
    }

    /// @notice Gets the amountConsumed value from the unique storage slot
    /// @return value The stored value
    function getAmountConsumed() internal view returns (uint256 value) {
        assembly {
            value := sload(AMOUNT_CONSUMED_SLOT)
        }
    }

    /// @notice Sets the ethAmount value in a unique storage slot
    /// @param value The value to set
    function setEthAmount(uint256 value) internal {
        assembly {
            sstore(ETH_AMOUNT_SLOT, value)
        }
    }

    /// @notice Gets the ethAmount value from the unique storage slot
    /// @return value The stored value
    function getEthAmount() internal view returns (uint256 value) {
        assembly {
            value := sload(ETH_AMOUNT_SLOT)
        }
    }
} 