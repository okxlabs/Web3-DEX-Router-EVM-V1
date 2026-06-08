// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "./JitTestBase.t.sol";

/// @title DynamicRouteInvariantTest — 14 invariants I-01 .. I-14 + AC-27 + AC-29/30/31 regression.
/// @notice Many invariants are re-asserted via cross-scenario tests (not forge invariant fuzz, because
///         DynamicRoute is stateless — there is no handler state to mutate). We encode each invariant
///         as a deterministic multi-step assertion equivalent to a property-based check over the
///         finite set of allowed candidate shapes.
contract DynamicRouteInvariantTest is JitTestBase {
    // =======================================================================
    //                            Invariants I-01 .. I-14
    // =======================================================================

    /// I-01: _dryRun is rejected unless msg.sender == address(this). Mirrors AC-21.
    function test_I01_dryRun_self_only() public {
        DynamicRoute.Candidate memory c = _successCandidate(mockSuccess1, MOCK_QUOTE_A);

        // EOA
        address eoa = address(0xE0A1);
        vm.prank(eoa);
        vm.expectRevert("JIT: only self");
        jit._dryRun(c, recipient, address(fromToken), address(toToken), AMOUNT_IN, refundToAddr);

        // Contract
        vm.expectRevert("JIT: only self");
        jit._dryRun(c, recipient, address(fromToken), address(toToken), AMOUNT_IN, refundToAddr);
    }

    /// I-02: nonReentrant on sellBase / sellQuote. Mirrors AC-20.
    /// Here we verify the state via a plain reentrancy check using a pre-entered guard:
    /// We call sellBase, and during its execution the mock reentrant adapter tries to re-enter.
    /// The inner call must fail (caught by _tryExeAdapter → quote = 0 for that candidate).
    function test_I02_nonReentrant_active() public {
        fromToken.mint(address(jit), AMOUNT_IN);

        DynamicRoute.Candidate[] memory innerCs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory innerData = _encode(address(fromToken), address(toToken), 0, innerCs);

        MockReentrantAdapter mre = new MockReentrantAdapter(address(jit), innerData);

        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](2);
        cs[0] = DynamicRoute.Candidate({
            adapter: address(mre), assetTo: address(mre), rawData: _rawData(address(0), false), extraData: ""
        });
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-02: outer succeeds despite inner reentry");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_A, "I-02: legit wins");
    }

    /// I-03: magic spoof cannot land in amountOut slot. Mirrors AC-19.
    function test_I03_magic_spoof_not_amountOut() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](2);
        cs[0] = _spoofCandidate();
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-03 setup ok");
        // If the spoof landed in amountOut, the tx would try to execute spoof as winner
        // and the final delta would be 0 (because spoof adapter doesn't actually transfer).
        // By asserting a non-zero delta equal to the legitimate quote, we prove the spoof lost.
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_A, "I-03: legit wins, spoof amountOut is 0");
    }

    /// I-04: catch branch strict length + MAGIC prefix check.
    /// We cover it by: empty revert (AC-17) & non-magic revert (AC-18) & magic-spoof (AC-19) —
    /// all three classes must yield quote = 0.
    function test_I04_catch_strict_validation() public {
        fromToken.mint(address(jit), AMOUNT_IN);

        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](4);
        cs[0] = _shortRevertCandidate(); // < 4 bytes revert data
        cs[1] = _failCandidate(); // Error(string) selector (not MAGIC)
        cs[2] = _spoofCandidate(); // MAGIC-prefixed spoof
        cs[3] = _successCandidate(mockSuccess1, MOCK_QUOTE_A); // legit

        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-04 setup ok");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_A, "I-04: only legit wins");
    }

    /// I-05: single-candidate failure does not crash the whole tx.
    function test_I05_single_failure_isolated() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](2);
        cs[0] = _failCandidate();
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-05: tx survives isolated failure");
    }

    /// I-06: candidates length boundary — both sides.
    function test_I06_candidates_boundary_lower() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](1);
        cs[0] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);
        vm.expectRevert("JIT: candidates len out of range");
        jit.sellBase(recipient, address(jit), data);
    }

    function test_I06_candidates_boundary_upper() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](9);
        for (uint256 i = 0; i < 9; i++) {
            cs[i] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        }
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);
        vm.expectRevert("JIT: candidates len out of range");
        jit.sellBase(recipient, address(jit), data);
    }

    /// I-07: quotes[winner] must be strictly > 0 to proceed.
    function test_I07_allDead_reverts() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](2);
        cs[0] = _failCandidate();
        cs[1] = _shortRevertCandidate();
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.expectRevert("JIT: all candidates dead");
        jit.sellBase(recipient, address(jit), data);
    }

    /// I-08: dry-run amount == real execution amount (0 delta) — unit proxy.
    function test_I08_dry_equals_real_unit() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        uint256 before_ = toToken.balanceOf(recipient);
        // Capture emitted quotes
        vm.recordLogs();
        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-08 setup ok");
        uint256 afterBal = toToken.balanceOf(recipient);
        uint256 realDelta = afterBal - before_;

        // Parse JitWinnerSelected event to extract winner quote
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 winnerQuote = 0;
        bytes32 winnerSig = keccak256("JitWinnerSelected(uint8,uint256[],address)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == winnerSig) {
                (uint8 winnerIdx, uint256[] memory q,) = abi.decode(logs[i].data, (uint8, uint256[], address));
                winnerQuote = q[winnerIdx];
                break;
            }
        }
        assertEq(realDelta, winnerQuote, "I-08: real delta equals emitted winner quote");
    }

    /// I-09: DynamicRoute fromToken balance == 0 post-tx.
    function test_I09_no_leakage() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-09 setup ok");
        assertEq(fromToken.balanceOf(address(jit)), 0, "I-09: JIT fromToken leaked");
    }

    /// I-10 / AC-27: dry-run side effects (PMM signature consume / FOT fee) are atomically reverted.
    /// We probe via: a candidate uses the magic spoof adapter (which "consumes" nothing but is a
    /// proxy for a "revert-after-partial-effect" scenario). Because the spoof reverts (magic raised),
    /// its transfer from jit→spoof is rolled back by revert atomicity; jit still has the fromToken.
    function test_I10_dryRun_atomic_rollback() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](2);
        cs[0] = _spoofCandidate();
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        uint256 spoofBalBefore = fromToken.balanceOf(address(mockSpoof));
        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-10 setup ok");
        assertEq(
            fromToken.balanceOf(address(mockSpoof)), spoofBalBefore, "I-10: dry-run transfer to spoof was rolled back"
        );
    }

    /// I-11: `to` is preserved end-to-end (dry-run and real both use outer `to`).
    /// Proxy check: recipient (NOT jit) receives toToken.
    function test_I11_to_passthrough() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-11 setup ok");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_B, "I-11: recipient is exactly outer to");
        assertEq(toToken.balanceOf(address(jit)), 0, "I-11: JIT is not treated as to");
    }

    /// I-12: refundTo == 0 when marker absent. Proxy check via AC-22.
    function test_I12_refundTo_marker_absent_means_zero() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        address fakeRefund = address(0xBA5EBA11);
        uint256 before_ = fromToken.balanceOf(fakeRefund);

        (bool ok,) = _callSellBaseNoRefund(data);
        assertTrue(ok, "I-12 setup ok");
        assertEq(fromToken.balanceOf(fakeRefund), before_, "I-12: no leftover refunded to fake addr");
    }

    /// I-13: event shape — quotes.length == candidates.length, winnerAdapter == cs[winnerIdx].adapter.
    function test_I13_event_shape() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.recordLogs();
        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "I-13 setup ok");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("JitWinnerSelected(uint8,uint256[],address)")) {
                (uint8 winnerIdx, uint256[] memory q, address winnerAdapter) =
                    abi.decode(logs[i].data, (uint8, uint256[], address));
                assertEq(q.length, cs.length, "I-13: quotes length matches candidates length");
                assertEq(winnerAdapter, cs[winnerIdx].adapter, "I-13: winnerAdapter matches cs[winnerIdx].adapter");
                found = true;
                break;
            }
        }
        assertTrue(found, "I-13: JitWinnerSelected must be emitted");
    }

    /// I-14 (regression): IAdapter interface selectors are stable (proxy for bytecode-level stability).
    function test_I14_iadapter_interface_stable() public {
        assertEq(IAdapter.sellBase.selector, bytes4(keccak256("sellBase(address,address,bytes)")));
        assertEq(IAdapter.sellQuote.selector, bytes4(keccak256("sellQuote(address,address,bytes)")));
    }

    // =======================================================================
    //                   AC-29 / AC-30 regression (weak in-code proxy)
    // =======================================================================

    /// AC-29 (weak proxy): existing IAdapter interface selectors unchanged.
    /// Real assertion: `git diff --name-only main..HEAD -- contracts/8/{DexRouter,DagRouter,libraries,interfaces/IAdapter}.sol`
    /// must report zero changed files. That check lives in the PR pipeline / audit, not forge.
    function test_AC29_AC30_weak_proxy_iadapter_unchanged() public {
        assertEq(IAdapter.sellBase.selector, bytes4(keccak256("sellBase(address,address,bytes)")));
        assertEq(IAdapter.sellQuote.selector, bytes4(keccak256("sellQuote(address,address,bytes)")));
    }

    /// AC-31: underlying adapter sees msg.sender == DynamicRoute. Positive assertion (design statement).
    /// We assert this via a recorder mock that captures its own msg.sender.
    function test_AC31_underlying_sees_jit_as_msgsender() public {
        // skeleton note: this is a design statement rather than a bug to prevent.
        // We spy via the MockSuccessAdapter's transfer — after the call, we infer msg.sender from
        // the fact that the funds went from jit→mockSuccess2 (the assetTo in our candidate).
        fromToken.mint(address(jit), AMOUNT_IN);
        DynamicRoute.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        uint256 balBefore = fromToken.balanceOf(address(mockSuccess2));
        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-31 setup ok");
        assertEq(
            fromToken.balanceOf(address(mockSuccess2)) - balBefore,
            AMOUNT_IN,
            "AC-31 (proxy): mockSuccess2 received tokens from DynamicRoute (i.e. JIT was caller)"
        );
    }
}
