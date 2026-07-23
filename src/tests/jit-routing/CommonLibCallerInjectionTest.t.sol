// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "forge-std/Test.sol";
import {IAdapter} from "@dex/interfaces/IAdapter.sol";
import {CommonLib} from "@dex/libraries/CommonLib.sol";
import "@dex/libraries/Constants.sol";

/// @dev Thin external wrapper so tests can drive the `internal` CommonLib.exeAdapter. Because the
///      library is inlined, `msg.sender` observed inside exeAdapter is whoever calls `callExe` — i.e.
///      the outermost caller, exactly as it would be the DexRouter's caller in production.
contract ExeAdapterCaller {
    function callExe(bool reverse, address adapter, address to, address pool, bytes memory moreinfo, address refundTo)
        external
    {
        CommonLib.exeAdapter(reverse, adapter, to, pool, moreinfo, refundTo);
    }
}

/// @dev Adapter that echoes the calldata-tail words the router injected: dexRouterCaller (-64, EXACT
///      marker match) and refundTo (-32, legacy ORIGIN_PAYER subset match). Records them for assertions.
contract EchoTailAdapter is IAdapter {
    address public lastDexRouterCaller;
    address public lastRefundTo;
    bool public called;

    function sellBase(address, address, bytes memory) external override {
        _record();
    }

    function sellQuote(address, address, bytes memory) external override {
        _record();
    }

    function _record() internal {
        address dexCaller;
        address refundDest;
        assembly {
            let w64 := calldataload(sub(calldatasize(), 64))
            if eq(and(w64, MARKER_MASK), DEX_ROUTER_CALLER_MARKER) { dexCaller := and(w64, _ADDRESS_MASK) }
            let w32 := calldataload(sub(calldatasize(), 32))
            if eq(and(w32, ORIGIN_PAYER), ORIGIN_PAYER) { refundDest := and(w32, _ADDRESS_MASK) }
        }
        lastDexRouterCaller = dexCaller;
        lastRefundTo = refundDest;
        called = true;
    }
}

/// @title CommonLib caller injection tests.
/// @notice Covers caller injection, spoof resistance, refund preservation, and marker validation.
contract CommonLibCallerInjectionTest is Test {
    ExeAdapterCaller internal caller;
    EchoTailAdapter internal echo;

    address internal trader = makeAddr("trader");
    address internal refundToAddr = makeAddr("refundTo");
    address internal to = address(0xBEEF);
    address internal pool = makeAddr("pool");

    function setUp() public {
        caller = new ExeAdapterCaller();
        echo = new EchoTailAdapter();
    }

    // ---------------------- Correct injection ----------------------

    /// The dexRouterCaller injected at -64 equals the outermost msg.sender of the routing call.
    function test_injects_outermost_caller() public {
        vm.prank(trader);
        caller.callExe(false, address(echo), to, pool, hex"", refundToAddr);
        assertEq(echo.lastDexRouterCaller(), trader, "-64 carries the outermost caller");
    }

    /// The reverse (sellQuote) path injects identically.
    function test_reverse_path_injects_caller() public {
        vm.prank(trader);
        caller.callExe(true, address(echo), to, pool, hex"", refundToAddr);
        assertEq(echo.lastDexRouterCaller(), trader, "reverse path injects caller");
    }

    // ---------------------- Spoof resistance ----------------------

    /// A user-controlled moreInfo carrying a fake DEX_ROUTER_CALLER_MARKER word cannot override the
    /// injected caller: exeAdapter appends the real word AFTER moreInfo, so -64 is always msg.sender.
    function test_moreInfo_cannot_forge_caller() public {
        address attacker = address(0xA77ACC);
        // moreInfo ends with a forged marker+attacker word — a naive reader could be fooled.
        bytes memory forgedMoreInfo = abi.encodePacked(DEX_ROUTER_CALLER_MARKER + uint256(uint160(attacker)));

        vm.prank(trader);
        caller.callExe(false, address(echo), to, pool, forgedMoreInfo, refundToAddr);

        assertEq(echo.lastDexRouterCaller(), trader, "injected caller is real msg.sender, not forged");
        assertTrue(echo.lastDexRouterCaller() != attacker, "attacker value never wins");
    }

    // ---------------------- refundTo at -32 preserved ----------------------

    /// refundTo keeps its historical position/marker at -32 alongside the new -64 word.
    function test_refundTo_preserved_at_minus32() public {
        vm.prank(trader);
        caller.callExe(false, address(echo), to, pool, hex"", refundToAddr);
        assertEq(echo.lastRefundTo(), refundToAddr, "refundTo still readable at -32");
        assertEq(echo.lastDexRouterCaller(), trader, "both tail words coexist");
    }

    // ---------------------- Exact-match fail-closed ----------------------

    /// A correctly-marked -64 word extracts the address (positive control for the exact match).
    function test_correct_marker_extracts_address() public {
        address injected = makeAddr("injected");
        _callEchoWithTail(DEX_ROUTER_CALLER_MARKER + uint256(uint160(injected)));
        assertEq(echo.lastDexRouterCaller(), injected, "correct marker extracts address");
    }

    /// A forged high-48-bit-all-1 word (NOT the exact marker) fails closed to address(0).
    function test_forged_all_ones_marker_fails_closed() public {
        address attacker = address(0xA77ACC);
        // High 6 bytes all-1 (would pass a subset match) but != DEX_ROUTER_CALLER_MARKER.
        _callEchoWithTail(MARKER_MASK | uint256(uint160(attacker)));
        assertEq(echo.lastDexRouterCaller(), address(0), "forged all-ones marker fails closed");
    }

    /// The legacy ORIGIN_PAYER marker (2ccc) at -64 is NOT mistaken for dexRouterCaller (2ddd).
    function test_origin_payer_marker_not_aliased() public {
        address someRefund = makeAddr("someRefund");
        _callEchoWithTail(ORIGIN_PAYER + uint256(uint160(someRefund)));
        assertEq(echo.lastDexRouterCaller(), address(0), "ORIGIN_PAYER marker never aliases as caller");
    }

    /// A completely unmarked -64 word (no marker bits) fails closed to address(0).
    function test_missing_marker_fails_closed() public {
        _callEchoWithTail(uint256(uint160(address(0xDEAD))));
        assertEq(echo.lastDexRouterCaller(), address(0), "missing marker fails closed");
    }

    // ---------------------- helper ----------------------

    /// @dev Calls the echo adapter directly with a crafted -64 word and a benign -32 word, mirroring the
    ///      exeAdapter tail layout so the adapter's exact-match extraction runs against attacker input.
    function _callEchoWithTail(uint256 word64) internal {
        bytes memory head = abi.encodeWithSelector(IAdapter.sellBase.selector, to, pool, hex"");
        bytes memory payload =
            abi.encodePacked(head, word64, ORIGIN_PAYER + uint256(uint160(refundToAddr)));
        (bool ok,) = address(echo).call(payload);
        require(ok, "echo call failed");
    }
}
