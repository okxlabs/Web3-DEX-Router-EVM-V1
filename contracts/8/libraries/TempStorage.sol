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
    // keccak256("okx.unxswap.v3.router.fromTokenCommissionAmount");
    bytes32 private constant FROM_TOKEN_COMMISSION_AMOUNT_SLOT = 0x14c08b7744401f3e01a1a1f2c397bb99b49e77a770c23cec6faec656e420ef1b;
    // keccak256("okx.unxswap.v3.router.newPayer");
    bytes32 private constant NEW_PAYER_SLOT = 0x4e2937ee94738cd0724dc82725afe014ff8cba49ff0ed184788be6d6895e8d24;

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

    /// @notice Sets the fromTokenCommissionAmount value in a unique storage slot
    /// @param value The value to set
    function setFromTokenCommissionAmount(uint256 value) internal {
        assembly {
            sstore(FROM_TOKEN_COMMISSION_AMOUNT_SLOT, value)
        }
    }

    /// @notice Gets the fromTokenCommissionAmount value from the unique storage slot
    /// @return value The stored value
    function getFromTokenCommissionAmount() internal view returns (uint256 value) {
        assembly {
            value := sload(FROM_TOKEN_COMMISSION_AMOUNT_SLOT)
        }
    }

    /// @notice Sets the newPayer value in a unique storage slot
    /// @param value The value to set
    function setNewPayer(address value) internal {
        assembly {
            sstore(NEW_PAYER_SLOT, value)
        }
    }

    /// @notice Gets the newPayer value from the unique storage slot
    /// @return value The stored value
    function getNewPayer() internal view returns (address value) {
        assembly {
            value := sload(NEW_PAYER_SLOT)
        }
    }
} 