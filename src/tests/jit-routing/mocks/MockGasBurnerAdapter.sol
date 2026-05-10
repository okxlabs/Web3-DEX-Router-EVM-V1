// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";

/// @notice Burns all gas allotted to it. Covers AC-16 / AC-24 (gas griefing).
contract MockGasBurnerAdapter is IAdapter {
    function sellBase(address, address, bytes memory) external view override {
        _burn();
    }

    function sellQuote(address, address, bytes memory) external view override {
        _burn();
    }

    function _burn() internal view {
        while (gasleft() > 1000) {
            // burn
        }
    }
}
