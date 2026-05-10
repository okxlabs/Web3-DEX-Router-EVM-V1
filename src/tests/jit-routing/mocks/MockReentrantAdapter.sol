// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";

interface IJitReentryTarget {
    function sellBase(address to, address pool, bytes memory data) external;
    function sellQuote(address to, address pool, bytes memory data) external;
}

/// @notice Calls back into JitAdapter.sellBase from within its own sellBase. Covers AC-20 (reentrancy).
contract MockReentrantAdapter is IAdapter {
    address public jitAdapter;
    bytes public reentryData;

    constructor(address _jit, bytes memory _reentryData) {
        jitAdapter = _jit;
        reentryData = _reentryData;
    }

    function sellBase(address to, address, bytes memory) external override {
        IJitReentryTarget(jitAdapter).sellBase(to, jitAdapter, reentryData);
    }

    function sellQuote(address to, address, bytes memory) external override {
        IJitReentryTarget(jitAdapter).sellBase(to, jitAdapter, reentryData);
    }
}
