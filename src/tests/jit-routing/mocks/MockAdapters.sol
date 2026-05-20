// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";
import "@dex/interfaces/IERC20.sol";
import "@dex/libraries/SafeERC20.sol";

/// @title MockAdapters — IAdapter fixtures used by the JIT routing test suite.
/// @notice Consolidates the six IAdapter behavioral mocks into one file. Each mock
///         is a minimal implementation of `IAdapter` exhibiting one specific
///         (honest or hostile) behavior; they are composed into Candidate[] arrays
///         by the JIT tests to exercise dry-run, post-exec verification, and
///         attack-vector defenses.
///
///         Layout:
///           - Honest fixtures:   MockSuccessAdapter
///           - Hostile fixtures:  MockFailAdapter, MockShortRevertAdapter,
///                                MockGasBurnerAdapter, MockMagicSpoofAdapter,
///                                MockReentrantAdapter

// =========================================================================
//                            HONEST FIXTURES
// =========================================================================

/// @notice Mock adapter that transfers a pre-configured amountOut of toToken to `to`.
/// @dev    extraData = abi.encode(address toToken, uint256 amountOut).
///         Pre-fund the mock adapter with `toToken` before use.
///         Requires `assetTo == address(mockSuccessAdapter)` in Candidate
///         (DynamicRoute transfers fromToken to adapter itself).
contract MockSuccessAdapter is IAdapter {
    function sellBase(
        address to,
        address,
        /*pool*/
        bytes memory data
    )
        external
        override
    {
        _execute(to, data);
    }

    function sellQuote(
        address to,
        address,
        /*pool*/
        bytes memory data
    )
        external
        override
    {
        _execute(to, data);
    }

    function _execute(address to, bytes memory data) internal {
        (address toToken, uint256 amountOut) = abi.decode(data, (address, uint256));
        SafeERC20.safeTransfer(IERC20(toToken), to, amountOut);
    }
}

// =========================================================================
//                            HOSTILE FIXTURES
// =========================================================================

/// @notice Reverts with a standard Error(string).
///         Covers AC-15 (winner real-exec failure) and AC-18 (underlying revert
///         bubbled as `underlyingReason`).
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

/// @notice Reverts with empty (0-byte) revert data; simulates OOG or bare `revert()`.
///         Covers AC-17 (short-revert path: dry-run treats as quote=0, no magic decode).
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

/// @notice Burns all forwarded gas down to ~1000. Covers AC-16 / AC-24 (gas griefing).
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

/// @notice Malicious mock that reverts with MAGIC-prefixed data claiming a huge amountOut.
///         Covers AC-19 (magic spoof). If DynamicRoute is vulnerable, this fake amount
///         would be picked as winner.
contract MockMagicSpoofAdapter is IAdapter {
    bytes4 public constant DRY_RUN_RESULT_MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"));
    uint256 public constant FAKE_AMOUNT = type(uint256).max;

    function sellBase(address, address, bytes memory) external pure override {
        _spoof();
    }

    function sellQuote(address, address, bytes memory) external pure override {
        _spoof();
    }

    function _spoof() internal pure {
        bytes memory data = abi.encodePacked(DRY_RUN_RESULT_MAGIC, abi.encode(FAKE_AMOUNT, true, bytes("")));
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}

/// @dev Minimal target interface used by MockReentrantAdapter to re-enter DynamicRoute.
interface IJitReentryTarget {
    function sellBase(address to, address pool, bytes memory data) external;
    function sellQuote(address to, address pool, bytes memory data) external;
}

/// @notice Calls back into DynamicRoute.sellBase from within its own sellBase.
///         Covers AC-20 (reentrancy — nonReentrant must block).
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
