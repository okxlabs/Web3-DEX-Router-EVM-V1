// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;
interface IAngstromAdapter {
    /// @notice Attestation data for a specific block
    struct Attestation {
        uint64 blockNumber; // The block number this attestation is valid for
        bytes unlockData; // 20 bytes validator address + signature bytes
    }
}