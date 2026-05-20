// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "forge-std/Test.sol";

import {DexRouter} from "@dex/DexRouter.sol";
import {DynamicRoute} from "@dex/adapter/DynamicRoute.sol";
import {IAdapter} from "@dex/interfaces/IAdapter.sol";

import {MockERC20} from "../common/mock/MockERC20.sol";
import {MockFailAdapter, MockSuccessAdapter} from "./mocks/MockAdapters.sol";

interface ITokenApproveProxy {
    function owner() external view returns (address);
    function addProxy(address proxy) external;
}

/// @title DynamicRouteRouterTest — Router-level integration happy-path tests.
/// @notice Verifies DynamicRoute behaves correctly when invoked through DexRouter.dagSwapTo.
///         Uses ETH mainnet fork to access the live TokenApproveProxy / TokenApprove infrastructure
///         (the same pattern as src/tests/transferMode/DagByInvest.t.sol).
contract DynamicRouteRouterTest is Test {
    // ---------------------------------------------------------------------
    // Mainnet infrastructure (mirrors CommonUtils.sol constants)
    // ---------------------------------------------------------------------
    ITokenApproveProxy constant tokenApproveProxy =
        ITokenApproveProxy(0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58);
    address constant tokenApprove = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;

    // ---------------------------------------------------------------------
    // Under test
    // ---------------------------------------------------------------------
    DexRouter internal router;
    DynamicRoute internal jit;

    // ---------------------------------------------------------------------
    // Mock tokens + candidate adapters
    // ---------------------------------------------------------------------
    MockERC20 internal fromToken;
    MockERC20 internal toToken;

    MockSuccessAdapter internal adapterA;
    MockSuccessAdapter internal adapterB;
    MockSuccessAdapter internal adapterC;
    MockFailAdapter internal adapterFail;

    // ---------------------------------------------------------------------
    // Actors + constants
    // ---------------------------------------------------------------------
    address internal user = makeAddr("jitUser");

    uint256 internal constant AMOUNT_IN = 1 ether;
    uint256 internal constant QUOTE_A = 100 ether;
    uint256 internal constant QUOTE_B = 200 ether;
    uint256 internal constant QUOTE_C = 150 ether;

    // Re-declared so vm.expectEmit can match against it.
    event JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter);

    function setUp() public {
        // Live infra for TokenApproveProxy + TokenApprove. Uses the `eth` RPC alias from foundry.toml.
        vm.createSelectFork("eth");

        // Fresh DexRouter, whitelisted through the live TokenApproveProxy.
        router = new DexRouter();
        vm.prank(tokenApproveProxy.owner());
        tokenApproveProxy.addProxy(address(router));

        // Fresh DynamicRoute.
        jit = new DynamicRoute();

        // Mock tokens.
        fromToken = new MockERC20("From", "FROM", 0);
        toToken = new MockERC20("To", "TO", 0);

        // Mock candidate adapters; pre-fund the success ones with toToken inventory so they can pay quotes.
        adapterA = new MockSuccessAdapter();
        adapterB = new MockSuccessAdapter();
        adapterC = new MockSuccessAdapter();
        adapterFail = new MockFailAdapter("FAIL");
        toToken.mint(address(adapterA), 1000 ether);
        toToken.mint(address(adapterB), 1000 ether);
        toToken.mint(address(adapterC), 1000 ether);

        // User funds + allowance to TokenApprove (the address the Router pulls from).
        fromToken.mint(user, AMOUNT_IN * 10);
        vm.prank(user);
        fromToken.approve(tokenApprove, type(uint256).max);
    }

    // =========================================================================
    // Router-HP-01:
    //   User → DexRouter.dagSwapTo → DynamicRoute → 2 candidates dry-run → higher wins.
    //   Verifies the entire end-to-end flow: token pull, piggyback assembly,
    //   JitWinnerSelected event, real-exec delivery to user, no leftover on jit/router.
    // =========================================================================
    function test_RouterHP01_two_candidates_higher_wins_via_router() public {
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](2);
        cs[0] = _successCandidate(adapterA, QUOTE_A);
        cs[1] = _successCandidate(adapterB, QUOTE_B);
        bytes memory jitPayload = abi.encode(address(fromToken), address(toToken), uint8(0), cs);

        DexRouter.BaseRequest memory baseRequest;
        baseRequest.fromToken = uint256(uint160(address(fromToken)));
        baseRequest.toToken = address(toToken);
        baseRequest.fromTokenAmount = AMOUNT_IN;
        baseRequest.minReturnAmount = QUOTE_B;
        baseRequest.deadLine = block.timestamp;

        DexRouter.RouterPath[] memory paths = _buildSingleJitPath(jitPayload);

        uint256 toBefore = toToken.balanceOf(user);
        uint256 fromBefore = fromToken.balanceOf(user);

        uint256[] memory quotes = new uint256[](2);
        quotes[0] = QUOTE_A;
        quotes[1] = QUOTE_B;
        vm.expectEmit(true, true, true, true, address(jit));
        emit JitWinnerSelected(1, quotes, address(adapterB));

        vm.prank(user);
        uint256 ret = router.dagSwapTo(uint256(0), user, baseRequest, paths);

        // Return value + recipient balance match the higher quote.
        assertEq(ret, QUOTE_B, "HP-01: router returnAmount == winner quote");
        assertEq(toToken.balanceOf(user) - toBefore, QUOTE_B, "HP-01: user receives winner quote");
        assertEq(fromBefore - fromToken.balanceOf(user), AMOUNT_IN, "HP-01: user paid exactly AMOUNT_IN");

        // No leftover anywhere in the routing infrastructure.
        assertEq(fromToken.balanceOf(address(jit)), 0, "HP-01: no fromToken on jit");
        assertEq(toToken.balanceOf(address(jit)), 0, "HP-01: no toToken on jit");
        assertEq(fromToken.balanceOf(address(router)), 0, "HP-01: no fromToken on router");
        assertEq(toToken.balanceOf(address(router)), 0, "HP-01: no toToken on router");
    }

    // =========================================================================
    // Router-HP-02:
    //   3 candidates, one of them reverts in dry-run — Router-level tx still succeeds with
    //   the surviving best candidate. Mirrors AC-18 / I-05 but via the Router entry.
    // =========================================================================
    function test_RouterHP02_failed_candidate_does_not_break_router() public {
        DynamicRoute.Candidate[] memory cs = new DynamicRoute.Candidate[](3);
        cs[0] = _successCandidate(adapterA, QUOTE_A);  // 100
        cs[1] = _failCandidate(adapterFail);            // dry-run fails -> quote = 0
        cs[2] = _successCandidate(adapterC, QUOTE_C);  // 150 ← winner
        bytes memory jitPayload = abi.encode(address(fromToken), address(toToken), uint8(0), cs);

        DexRouter.BaseRequest memory baseRequest;
        baseRequest.fromToken = uint256(uint160(address(fromToken)));
        baseRequest.toToken = address(toToken);
        baseRequest.fromTokenAmount = AMOUNT_IN;
        baseRequest.minReturnAmount = QUOTE_C;
        baseRequest.deadLine = block.timestamp;

        DexRouter.RouterPath[] memory paths = _buildSingleJitPath(jitPayload);

        uint256 toBefore = toToken.balanceOf(user);

        vm.prank(user);
        uint256 ret = router.dagSwapTo(uint256(0), user, baseRequest, paths);

        // Failed dry-run is isolated; surviving best (C at idx=2) wins.
        assertEq(ret, QUOTE_C, "HP-02: surviving best wins");
        assertEq(toToken.balanceOf(user) - toBefore, QUOTE_C, "HP-02: user receives surviving winner");
        assertEq(fromToken.balanceOf(address(jit)), 0, "HP-02: no fromToken leak on jit");
    }

    // ---------------------------------------------------------------------
    // Path / candidate / rawData helpers
    // ---------------------------------------------------------------------

    function _buildSingleJitPath(bytes memory jitPayload)
        internal
        view
        returns (DexRouter.RouterPath[] memory paths)
    {
        paths = new DexRouter.RouterPath[](1);
        paths[0].mixAdapters = new address[](1);
        paths[0].mixAdapters[0] = address(jit);

        paths[0].assetTo = new address[](1);
        // Router transfers fromToken to assetTo before invoking the adapter. We point at JIT
        // itself so that JIT.balanceOf(this, fromToken) == AMOUNT_IN when _runJit starts.
        paths[0].assetTo[0] = address(jit);

        paths[0].rawData = new uint256[](1);
        paths[0].rawData[0] = _routerEdgeRawData();

        paths[0].extraData = new bytes[](1);
        paths[0].extraData[0] = jitPayload;

        paths[0].fromToken = uint256(uint160(address(fromToken)));
    }

    /// @dev DagRouter expects rawData with: weight (bits 160..175), outputIdx (bits 176..183),
    ///      inputIdx (bits 184..191), reverse bit (bit 255), pool (low 160 bits).
    ///      Here: single node single edge: in=0, out=1, weight=10000. Pool unused by JIT.
    function _routerEdgeRawData() internal pure returns (uint256) {
        return (uint256(10000) << 160) | (uint256(1) << 176);
    }

    function _successCandidate(MockSuccessAdapter m, uint256 quote)
        internal
        view
        returns (DynamicRoute.Candidate memory)
    {
        bytes memory extra = abi.encode(address(toToken), quote);
        return DynamicRoute.Candidate({
            adapter: address(m),
            assetTo: address(m),
            rawData: 0, // Candidate-level rawData: no reverse, no pool (mock ignores both).
            extraData: extra
        });
    }

    function _failCandidate(MockFailAdapter m) internal pure returns (DynamicRoute.Candidate memory) {
        return DynamicRoute.Candidate({
            adapter: address(m),
            assetTo: address(m),
            rawData: 0,
            extraData: ""
        });
    }
}
