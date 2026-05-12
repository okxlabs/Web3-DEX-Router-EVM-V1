// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IERC20.sol";
import "../libraries/CommonLib.sol";
import "../libraries/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title JitAdapter — Just-In-Time dynamic routing adapter
/// @notice Implements IAdapter.sellBase / sellQuote. For each call, dry-runs every packed candidate via
///         a magic-prefixed revert-with-data pattern, picks the candidate with the highest measured
///         amountOut, then really executes that winner. No fallback: winner real-exec failure bubbles up.
/// @dev Immutable, no admin, no upgrade, no storage state (only ReentrancyGuard._status slot).
contract JitAdapter is IAdapter, CommonLib, ReentrancyGuard {
    // =========================== Constants ===========================

    uint8 internal constant MODE_AUTO = 0;
    uint256 internal constant MIN_CANDIDATES = 2;
    uint256 internal constant MAX_CANDIDATES = 255;

    /// @dev Public for Stage 3 test assertability. TD §Phase 2 declared this `internal`; `public` adds
    ///      zero mutability surface (still a constant) but lets unit tests assert non-collision with
    ///      Error(string) / Panic(uint256) / IAdapter selectors. Safe.
    bytes4 public constant DRY_RUN_RESULT_MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"));

    // =========================== Struct ===========================

    struct Candidate {
        address adapter;
        address assetTo;
        uint256 rawData;
        bytes extraData;
    }

    // =========================== Events ===========================

    event JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter);
    event JitDryRunFailed(uint8 candidateIdx, address adapter, bytes reason);

    // =========================== External entry points ===========================

    /// @inheritdoc IAdapter
    function sellBase(
        address to,
        address,
        /*pool*/
        bytes memory data
    )
        external
        override
        nonReentrant
    {
        _runJit(to, data);
    }

    /// @inheritdoc IAdapter
    function sellQuote(
        address to,
        address,
        /*pool*/
        bytes memory data
    )
        external
        override
        nonReentrant
    {
        _runJit(to, data);
    }

    // =========================== Internal self-call entry ===========================

    /// @dev External so `_dryRunSafe` can `this._dryRun(...)` self-call. Per-call gas forwarding is
    ///      enforced at the Router layer, not here — JitAdapter intentionally does not partition gas
    ///      between candidates.
    ///      Always terminates with a magic-prefixed revert; the normal return path is never taken.
    ///      `msg.sender == address(this)` guard prevents external callers from abusing this entrypoint.
    function _dryRun(
        Candidate calldata c,
        address to,
        address fromToken,
        address toToken,
        uint256 amount,
        address refundTo
    ) external {
        require(msg.sender == address(this), "JIT: only self");

        SafeERC20.safeTransfer(IERC20(fromToken), c.assetTo, amount);

        (bool reverse, address pool) = _decodeRawData(c.rawData);
        uint256 prev = IERC20(toToken).balanceOf(to);

        (bool ok, bytes memory underlyingReason) = _tryExeAdapter(reverse, c.adapter, to, pool, c.extraData, refundTo);

        uint256 amountOut = ok ? IERC20(toToken).balanceOf(to) - prev : 0;

        bytes memory ret =
            abi.encodePacked(DRY_RUN_RESULT_MAGIC, abi.encode(amountOut, ok, ok ? bytes("") : underlyingReason));
        assembly {
            revert(add(ret, 32), mload(ret))
        }
    }

    // =========================== Core flow ===========================

    function _runJit(address to, bytes memory data) internal {
        (address fromToken, address toToken, uint8 mode, Candidate[] memory cs) =
            abi.decode(data, (address, address, uint8, Candidate[]));

        require(mode == MODE_AUTO, "JIT: unsupported mode");
        require(
            cs.length >= MIN_CANDIDATES && cs.length <= MAX_CANDIDATES, "JIT: candidates len out of range"
        );
        require(fromToken != _ETH && toToken != _ETH, "JIT: native ETH not allowed; use WETH");

        uint256 amount = IERC20(fromToken).balanceOf(address(this));
        require(amount > 0, "JIT: zero input");

        address refundTo = _extractRefundTo();

        uint256[] memory quotes = new uint256[](cs.length);
        for (uint256 i; i < cs.length; ++i) {
            quotes[i] = _dryRunSafe(cs[i], to, fromToken, toToken, amount, refundTo, uint8(i));
        }

        uint8 winner = _findMax(quotes);
        require(quotes[winner] > 0, "JIT: all candidates dead");

        (bool reverseW, address poolW) = _decodeRawData(cs[winner].rawData);
        SafeERC20.safeTransfer(IERC20(fromToken), cs[winner].assetTo, amount);
        _exeAdapter(reverseW, cs[winner].adapter, to, poolW, cs[winner].extraData, refundTo);

        emit JitWinnerSelected(winner, quotes, cs[winner].adapter);
    }

    function _dryRunSafe(
        Candidate memory c,
        address to,
        address fromToken,
        address toToken,
        uint256 amount,
        address refundTo,
        uint8 idx
    ) internal returns (uint256 amountOut) {
        try this._dryRun(c, to, fromToken, toToken, amount, refundTo) {
            // _dryRun always reverts with magic — this path is defensive only.
            return 0;
        } catch (bytes memory data) {
            if (data.length < 4) return 0;
            bytes4 sel;
            assembly {
                sel := mload(add(data, 32))
            }
            if (sel != DRY_RUN_RESULT_MAGIC) return 0;

            bytes memory inner = _stripMagic(data);
            (uint256 out, bool ok, bytes memory reason) = abi.decode(inner, (uint256, bool, bytes));
            if (!ok) {
                emit JitDryRunFailed(idx, c.adapter, reason);
                return 0;
            }
            return out;
        }
    }

    /// @dev Mirrors CommonLib._exeAdapter's calldata layout (selector + args + ORIGIN_PAYER + refundTo)
    ///      but returns (ok, returndata) instead of bubbling. Used only on the dry-run path so that a
    ///      malicious adapter cannot forge the OUTER magic-prefixed revert — its forged bytes land only
    ///      in the `underlyingReason` slot of the payload.
    function _tryExeAdapter(
        bool reverse,
        address adapter,
        address to,
        address pool,
        bytes memory extraData,
        address refundTo
    ) internal returns (bool ok, bytes memory returndata) {
        bytes4 sel = reverse ? IAdapter.sellQuote.selector : IAdapter.sellBase.selector;
        bytes memory callData = abi.encodePacked(
            abi.encodeWithSelector(sel, to, pool, extraData), ORIGIN_PAYER + uint256(uint160(refundTo))
        );
        (ok, returndata) = address(adapter).call(callData);
    }

    // =========================== Pure helpers ===========================

    /// @dev argmax. All-zero input returns 0; caller then rejects via `quotes[winner] == 0` check.
    function _findMax(uint256[] memory quotes) internal pure returns (uint8 winner) {
        uint256 maxVal = quotes[0];
        winner = 0;
        for (uint256 i = 1; i < quotes.length; ++i) {
            if (quotes[i] > maxVal) {
                maxVal = quotes[i];
                winner = uint8(i);
            }
        }
    }

    /// @dev Returns data[4:]. Caller must pre-validate `data.length >= 4`.
    function _stripMagic(bytes memory data) internal pure returns (bytes memory inner) {
        uint256 newLen = data.length - 4;
        inner = new bytes(newLen);
        for (uint256 i; i < newLen; ++i) {
            inner[i] = data[i + 4];
        }
    }

    /// @dev Mirrors DagRouter._exeEdge's raw decode: pool in low 160 bits, reverse flag at bit 255.
    function _decodeRawData(uint256 rawData) internal pure returns (bool reverse, address pool) {
        assembly {
            pool := and(rawData, _ADDRESS_MASK)
            reverse := iszero(iszero(and(rawData, _REVERSE_MASK)))
        }
    }

    /// @dev Reads last-32 calldata bytes, validates ORIGIN_PAYER marker, returns refundTo.
    ///      Marker mismatch -> refundTo == 0 (underlying adapter then skips leftover refund).
    ///      Mirrors UniV3Adapter._uniV3Swap's extraction pattern.
    function _extractRefundTo() internal pure returns (address refundTo) {
        assembly {
            let payerOrigin := calldataload(sub(calldatasize(), 32))
            if eq(and(payerOrigin, ORIGIN_PAYER), ORIGIN_PAYER) {
                refundTo := and(payerOrigin, _ADDRESS_MASK)
            }
        }
    }

    // Deliberately NO `receive()` / `payable fallback()` — native ETH send reverts (S-24).
}
