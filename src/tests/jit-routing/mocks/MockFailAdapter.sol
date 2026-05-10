// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";

/// @notice Reverts with a standard Error(string). Covers AC-15 (winner real-exec failure) and AC-18 (underlying revert bubbled as underlyingReason).
contract MockFailAdapter is IAdapter {
    string public failureMessage;

    constructor(string memory _msg) {
        failureMessage = _msg;
    }

    function sellBase(address, address, bytes memory) external view override {
        revert(failureMessage);
    }

    function sellQuote(address, address, bytes memory) external view override {
        revert(failureMessage);
    }
}
