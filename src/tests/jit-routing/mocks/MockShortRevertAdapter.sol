// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";

/// @notice Reverts with empty (0 byte) revert data; simulates OOG or bare `revert()`. Covers AC-17.
contract MockShortRevertAdapter is IAdapter {
    function sellBase(address, address, bytes memory) external pure override {
        assembly {
            revert(0, 0)
        }
    }

    function sellQuote(address, address, bytes memory) external pure override {
        assembly {
            revert(0, 0)
        }
    }
}
