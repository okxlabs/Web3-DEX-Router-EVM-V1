// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {IAdapter} from "@dex/interfaces/IAdapter.sol";
import {JitAdapter} from "@dex/adapter/JitAdapter.sol";

import {MockERC20} from "../common/mock/MockERC20.sol";
import {MockFOTToken} from "./mocks/MockFOTToken.sol";
import {
    MockFailAdapter,
    MockGasBurnerAdapter,
    MockMagicSpoofAdapter,
    MockReentrantAdapter,
    MockShortRevertAdapter,
    MockSuccessAdapter
} from "./mocks/MockAdapters.sol";

/// @title JitTestBase — shared setup for JIT routing test skeleton (RED).
abstract contract JitTestBase is Test {
    // Re-declared here so `vm.expectEmit` can match against them.
    // Signatures MUST stay in lock-step with JitAdapter.sol.
    event JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter);
    event JitDryRunFailed(uint8 candidateIdx, address adapter, bytes reason);

    // -- Deployed under test --
    JitAdapter internal jit;

    // -- Mock tokens --
    MockERC20 internal fromToken;
    MockERC20 internal toToken;
    MockFOTToken internal fotToken;

    // -- Mock adapters --
    MockSuccessAdapter internal mockSuccess1;
    MockSuccessAdapter internal mockSuccess2;
    MockMagicSpoofAdapter internal mockSpoof;
    MockGasBurnerAdapter internal mockGas;
    MockFailAdapter internal mockFail;
    MockShortRevertAdapter internal mockShort;

    // -- Constants mirrored from CommonUtils --
    address internal constant _ETH_SENTINEL = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant ORIGIN_PAYER_MARKER = 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
    uint256 internal constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 internal constant REVERSE_BIT = 0x8000000000000000000000000000000000000000000000000000000000000000;

    // -- Actors --
    address internal recipient = address(0xBEEF);
    address internal refundToAddr = address(0xC0FFEE);

    uint256 internal constant AMOUNT_IN = 1 ether;
    uint256 internal constant MOCK_QUOTE_A = 100 ether;
    uint256 internal constant MOCK_QUOTE_B = 200 ether;
    uint256 internal constant MOCK_QUOTE_C = 300 ether;

    function setUp() public virtual {
        jit = new JitAdapter();

        fromToken = new MockERC20("From", "FROM", 0);
        toToken = new MockERC20("To", "TO", 0);
        fotToken = new MockFOTToken("FeeToken", "FEE", 100); // 1% fee

        mockSuccess1 = new MockSuccessAdapter();
        mockSuccess2 = new MockSuccessAdapter();
        mockSpoof = new MockMagicSpoofAdapter();
        mockGas = new MockGasBurnerAdapter();
        mockFail = new MockFailAdapter("FAIL_REASON_XYZ");
        mockShort = new MockShortRevertAdapter();

        // Pre-fund mock adapters with toToken so they can pay out fake quotes
        toToken.mint(address(mockSuccess1), 1000 ether);
        toToken.mint(address(mockSuccess2), 1000 ether);
    }

    // --------------------------- Candidate helpers ---------------------------

    function _rawData(address pool, bool reverse) internal pure returns (uint256 rd) {
        rd = uint256(uint160(pool));
        if (reverse) rd |= REVERSE_BIT;
    }

    function _successCandidate(MockSuccessAdapter m, uint256 quote)
        internal
        view
        returns (JitAdapter.Candidate memory)
    {
        bytes memory extra = abi.encode(address(toToken), quote);
        return JitAdapter.Candidate({
            adapter: address(m), assetTo: address(m), rawData: _rawData(address(0), false), extraData: extra
        });
    }

    function _spoofCandidate() internal view returns (JitAdapter.Candidate memory) {
        return JitAdapter.Candidate({
            adapter: address(mockSpoof),
            assetTo: address(mockSpoof),
            rawData: _rawData(address(0), false),
            extraData: ""
        });
    }

    function _gasBurnerCandidate() internal view returns (JitAdapter.Candidate memory) {
        return JitAdapter.Candidate({
            adapter: address(mockGas), assetTo: address(mockGas), rawData: _rawData(address(0), false), extraData: ""
        });
    }

    function _failCandidate() internal view returns (JitAdapter.Candidate memory) {
        return JitAdapter.Candidate({
            adapter: address(mockFail), assetTo: address(mockFail), rawData: _rawData(address(0), false), extraData: ""
        });
    }

    function _shortRevertCandidate() internal view returns (JitAdapter.Candidate memory) {
        return JitAdapter.Candidate({
            adapter: address(mockShort),
            assetTo: address(mockShort),
            rawData: _rawData(address(0), false),
            extraData: ""
        });
    }

    // --------------------------- ExtraData encoding ---------------------------

    function _encode(address from_, address to_, uint8 mode, JitAdapter.Candidate[] memory cs)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(from_, to_, mode, cs);
    }

    function _buildSimplePair(uint256 qA, uint256 qB) internal view returns (JitAdapter.Candidate[] memory cs) {
        cs = new JitAdapter.Candidate[](2);
        cs[0] = _successCandidate(mockSuccess1, qA);
        cs[1] = _successCandidate(mockSuccess2, qB);
    }

    // --------------------------- Calldata helpers ---------------------------

    /// @dev Direct sellBase call (no ORIGIN_PAYER tail). Simulates a direct caller (no DagRouter).
    function _callSellBaseNoRefund(bytes memory data) internal returns (bool ok, bytes memory ret) {
        return _lowLevelCall(IAdapter.sellBase.selector, data, address(0), false);
    }

    /// @dev Sells with appended ORIGIN_PAYER marker + refundTo, mirroring CommonLib._exeAdapter tail.
    function _callSellBaseWithRefund(bytes memory data, address rTo) internal returns (bool ok, bytes memory ret) {
        return _lowLevelCall(IAdapter.sellBase.selector, data, rTo, true);
    }

    function _callSellQuoteWithRefund(bytes memory data, address rTo) internal returns (bool ok, bytes memory ret) {
        return _lowLevelCall(IAdapter.sellQuote.selector, data, rTo, true);
    }

    function _lowLevelCall(bytes4 sel, bytes memory data, address rTo, bool withRefund)
        internal
        returns (bool ok, bytes memory ret)
    {
        bytes memory head = abi.encodeWithSelector(sel, recipient, address(jit), data);
        if (withRefund) {
            bytes memory payload = abi.encodePacked(head, ORIGIN_PAYER_MARKER + uint256(uint160(rTo)));
            (ok, ret) = address(jit).call(payload);
        } else {
            (ok, ret) = address(jit).call(head);
        }
    }
}
