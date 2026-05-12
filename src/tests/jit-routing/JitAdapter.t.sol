// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "./JitTestBase.t.sol";

/// @title JitAdapterTest — main AC coverage.
/// @notice Covers AC-01 … AC-18, AC-25, AC-26, AC-28 plus MAGIC collision / constant value assertions.
contract JitAdapterTest is JitTestBase {
    // =======================================================================
    //                        AC-01 .. AC-06 (Happy Path)
    // =======================================================================

    /// AC-01: two-candidate unit scenario, higher quote wins.
    ///        Fork-level AC-01 (real UniV2 + UniV3) is deferred to Stage 4 fork suite; unit mirror retained here.
    function test_AC01_two_candidates_higher_wins() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.expectEmit(true, true, true, true, address(jit));
        emit JitWinnerSelected(1, _quotesArr(MOCK_QUOTE_A, MOCK_QUOTE_B), address(mockSuccess2));

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-01: sellBase must succeed");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_B, "AC-01: recipient receives winner quote");
    }

    /// AC-02: winner position can be either 0 or 1.
    function test_AC02_winner_is_zero() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_B, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-02: sellBase must succeed");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_B, "AC-02 winner=0");
    }

    function test_AC02_winner_is_one() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-02: sellBase must succeed");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_B, "AC-02 winner=1");
    }

    /// AC-03: sellQuote (reverse path) mirrors sellBase.
    function test_AC03_sellQuote_path() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellQuoteWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-03: sellQuote must succeed");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_B, "AC-03: recipient receives max quote");
    }

    /// AC-04: three candidates, PMM (here: success #2) wins.
    function test_AC04_three_candidates_pmm_wins() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](3);
        cs[0] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        cs[1] = _successCandidate(mockSuccess2, MOCK_QUOTE_C); // "PMM" highest
        // third: reuse success1 via fresh adapter to keep struct diverse
        MockSuccessAdapter success3 = new MockSuccessAdapter();
        toToken.mint(address(success3), 1000 ether);
        cs[2] = _successCandidate(success3, MOCK_QUOTE_B);

        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-04: sellBase must succeed");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_C, "AC-04: 3-cand winner = PMM quote");
    }

    /// AC-05: candidates length exactly 2 (the lower bound) is legal.
    function test_AC05_boundary_two_candidates_ok() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-05: len==2 must succeed");
    }

    /// AC-06: after a successful swap, JitAdapter has zero fromToken balance (no leakage).
    function test_AC06_no_token_leftover_in_jit() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-06 setup: sellBase must succeed");
        assertEq(fromToken.balanceOf(address(jit)), 0, "AC-06: no fromToken leftover");
        assertEq(toToken.balanceOf(address(jit)), 0, "AC-06: no toToken leftover");
    }

    // =======================================================================
    //                         AC-07 .. AC-14 (Boundary)
    // =======================================================================

    /// AC-07: candidates length 1 reverts CandidatesOutOfRange(1).
    function test_AC07_revert_candidates_len_one() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](1);
        cs[0] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.expectRevert("JIT: candidates len out of range");
        jit.sellBase(recipient, address(jit), data);
    }

    /// AC-08: length 255 is legal; tx must not uint8-overflow on winner selection.
    function test_AC08_boundary_255_candidates_ok() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](255);
        for (uint256 i = 0; i < 255; i++) {
            cs[i] = _successCandidate(mockSuccess1, MOCK_QUOTE_A + i);
        }
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-08: 255 candidates must not uint8-overflow");
        // winner index is 254 (highest quote)
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_A + 254, "AC-08: winner quote at idx 254");
    }

    /// AC-09: length 256 reverts CandidatesOutOfRange(256).
    function test_AC09_revert_candidates_len_256() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](256);
        for (uint256 i = 0; i < 256; i++) {
            cs[i] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        }
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.expectRevert("JIT: candidates len out of range");
        jit.sellBase(recipient, address(jit), data);
    }

    /// AC-10: all dry-runs fail → AllCandidatesDead revert.
    function test_AC10_all_dead_reverts() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](2);
        cs[0] = _failCandidate();
        cs[1] = _shortRevertCandidate();
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.expectRevert("JIT: all candidates dead");
        jit.sellBase(recipient, address(jit), data);
    }

    /// AC-11: mode != 0 reverts UnsupportedMode.
    function test_AC11_revert_mode_not_auto() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 1, cs);

        vm.expectRevert("JIT: unsupported mode");
        jit.sellBase(recipient, address(jit), data);
    }

    /// AC-12: fromToken == _ETH reverts NativeEthNotAllowed.
    function test_AC12_revert_native_fromToken() public {
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(_ETH_SENTINEL, address(toToken), 0, cs);

        vm.expectRevert("JIT: native ETH not allowed; use WETH");
        jit.sellBase(recipient, address(jit), data);
    }

    /// AC-13: toToken == _ETH reverts NativeEthNotAllowed.
    function test_AC13_revert_native_toToken() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), _ETH_SENTINEL, 0, cs);

        vm.expectRevert("JIT: native ETH not allowed; use WETH");
        jit.sellBase(recipient, address(jit), data);
    }

    /// AC-14: JitAdapter has 0 fromToken balance → ZeroInput revert.
    function test_AC14_revert_zero_input() public {
        // Intentionally not minting fromToken to jit
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        vm.expectRevert("JIT: zero input");
        jit.sellBase(recipient, address(jit), data);
    }

    // =======================================================================
    //                     AC-16 .. AC-18 (Exception / Revert)
    // =======================================================================

    /// AC-16: a gas-burner candidate consumes the gas forwarded to its dry-run — survivor still wins
    ///        thanks to EVM's 63/64 gas-forwarding rule (per-call gas limiting is a Router-layer concern).
    function test_AC16_gas_burner_isolated() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](2);
        cs[0] = _gasBurnerCandidate();
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-16: gas burner must not tank the tx");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_A, "AC-16: survivor wins");
    }

    /// AC-17: underlying returns < 4-byte revert data → dry-run treats as quote=0, no magic decode.
    function test_AC17_short_revert_is_zero_quote() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](2);
        cs[0] = _shortRevertCandidate();
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-17: short revert must not crash tx");
        assertEq(toToken.balanceOf(recipient), MOCK_QUOTE_A, "AC-17: survivor wins");
    }

    /// AC-18: Error(string) revert from underlying becomes underlyingReason in JitDryRunFailed event.
    function test_AC18_error_string_becomes_reason() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](2);
        cs[0] = _failCandidate();
        cs[1] = _successCandidate(mockSuccess1, MOCK_QUOTE_A);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        // Expect JitDryRunFailed with the Error(string) payload for "FAIL_REASON_XYZ"
        bytes memory expectedReason = abi.encodeWithSignature("Error(string)", "FAIL_REASON_XYZ");
        vm.expectEmit(true, true, true, true, address(jit));
        emit JitDryRunFailed(0, address(mockFail), expectedReason);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-18: one bad + one good -> survivor wins, tx ok");
    }

    // =======================================================================
    //                     AC-25 / AC-26 / AC-28 (Invariant Assertions)
    // =======================================================================

    /// AC-25 (unit mirror): dryRunAmountOut == realExecutionAmountOut for the winner in a simple mock pair.
    /// Full 0-diff assertion against real UniV3/UniV2/PMM belongs to Stage 4 fork suite; here we just
    /// assert the JitWinnerSelected quote equals the actual delta on recipient.
    function test_AC25_dry_equals_real_simple() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        uint256 balBefore = toToken.balanceOf(recipient);
        vm.recordLogs();
        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-25 setup ok");
        uint256 delta = toToken.balanceOf(recipient) - balBefore;
        assertEq(delta, MOCK_QUOTE_B, "AC-25: real delta equals winner quote");
    }

    /// AC-26: same as AC-06 for documentation coverage.
    function test_AC26_no_leftover_on_jit() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-26 setup ok");
        assertEq(fromToken.balanceOf(address(jit)), 0, "AC-26: from leftover zero");
    }

    /// AC-28: emitted quotes array length matches candidates.length; winnerAdapter matches cs[winnerIdx].
    function test_AC28_event_shape() public {
        fromToken.mint(address(jit), AMOUNT_IN);
        JitAdapter.Candidate[] memory cs = _buildSimplePair(MOCK_QUOTE_A, MOCK_QUOTE_B);
        bytes memory data = _encode(address(fromToken), address(toToken), 0, cs);

        uint256[] memory expectedQuotes = _quotesArr(MOCK_QUOTE_A, MOCK_QUOTE_B);
        vm.expectEmit(true, true, true, true, address(jit));
        emit JitWinnerSelected(1, expectedQuotes, address(mockSuccess2));

        (bool ok,) = _callSellBaseWithRefund(data, refundToAddr);
        assertTrue(ok, "AC-28: sellBase ok");
    }

    // =======================================================================
    //                  MAGIC constant value + collision assertions (D-2)
    // =======================================================================

    /// T-MAGIC-01: MAGIC constant is the keccak256 truncation of the locked string.
    function test_MAGIC_01_value_matches_spec() public {
        bytes4 expected = bytes4(keccak256("JIT_DRY_RUN_RESULT"));
        assertEq(jit.DRY_RUN_RESULT_MAGIC(), expected, "MAGIC must equal keccak256('JIT_DRY_RUN_RESULT')[:4]");
    }

    /// T-MAGIC-02: MAGIC does not collide with Solidity standard error selectors.
    function test_MAGIC_02_no_collision_with_std_errors() public {
        bytes4 magic = jit.DRY_RUN_RESULT_MAGIC();
        assertTrue(magic != bytes4(0x08c379a0), "collision: Error(string)");
        assertTrue(magic != bytes4(0x4e487b71), "collision: Panic(uint256)");
    }

    /// T-MAGIC-03: MAGIC does not collide with IAdapter function selectors.
    function test_MAGIC_03_no_collision_with_iadapter_selectors() public {
        bytes4 magic = jit.DRY_RUN_RESULT_MAGIC();
        assertTrue(magic != IAdapter.sellBase.selector, "collision: sellBase");
        assertTrue(magic != IAdapter.sellQuote.selector, "collision: sellQuote");
    }

    // =======================================================================
    //                              Utility
    // =======================================================================

    function _quotesArr(uint256 a, uint256 b) internal pure returns (uint256[] memory q) {
        q = new uint256[](2);
        q[0] = a;
        q[1] = b;
    }
}
