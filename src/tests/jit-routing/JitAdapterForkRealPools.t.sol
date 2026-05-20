// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {JitAdapter} from "@dex/adapter/JitAdapter.sol";
import {UniV3Adapter} from "@dex/adapter/UniV3Adapter.sol";
import {CurveStableNGAdapter} from "@dex/adapter/CurveStableNGAdapter.sol";
import {IAdapter} from "@dex/interfaces/IAdapter.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";

/// @title JitAdapterForkRealPoolsTest
/// @notice Fork-level audit gate: validates JitAdapter's core invariant
///         `dryRunQuote == realExecDelta` when candidates are REAL production
///         adapters (UniV3Adapter / CurveStableNGAdapter) pointing at REAL on-chain
///         pools. All prior tests use mocks whose dry-run and real-exec behavior
///         is trivially identical — this is the first test that exercises real
///         AMM state machines through dry-run revert atomicity.
///
/// @dev    HOW TO RUN:
///           FOUNDRY_TEST=src/tests/jit-routing FOUNDRY_EVM_VERSION=cancun \
///             forge test --match-path src/tests/jit-routing/JitAdapterForkRealPools.t.sol -vv
///
///         The `cancun` EVM version is REQUIRED because the Curve Stableswap-NG
///         pool uses TSTORE/TLOAD opcodes (transient storage, Cancun-only).
///         The repo's default `evm_version = "london"` in foundry.toml fails with
///         `NotActivated EvmError` on `coins(uint256)` when running this test
///         without the override.
contract JitAdapterForkRealPoolsTest is Test {
    // --- Tokens ---
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // --- Pools (verified on mainnet, all WETH/USDT) ---
    /// UniV3 0.01% fee tier (token0=WETH, token1=USDT, fee=100)
    address constant UNIV3_POOL = 0xc7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b;
    /// SushiSwap V3 0.05% fee tier (UniV3-fork, same callback signature)
    address constant SUSHI_V3_POOL = 0x72c2178E082feDB13246877B5aA42ebcE1b72218;
    /// Curve Stableswap-NG WETH/USDT (N_COINS=2, coins[0]=WETH, coins[1]=USDT)
    address constant CURVE_SNG_POOL = 0x6FB1dca86AAA76af74e8532D764E6F8848010767;

    // --- JitAdapter / candidate adapter / trailer constants ---
    uint256 constant ORIGIN_PAYER = 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;

    // --- Deployed under test ---
    JitAdapter internal jit;
    UniV3Adapter internal univ3Adapter; // serves both Uni V3 and Sushi V3
    CurveStableNGAdapter internal curveAdapter;

    address internal user = makeAddr("forkUser");
    address internal refundTo = makeAddr("forkRefund");

    event JitWinnerSelected(uint8 winnerIdx, uint256[] quotes, address winnerAdapter);
    event JitDryRunFailed(uint8 candidateIdx, address adapter, bytes reason);

    function setUp() public {
        vm.createSelectFork("eth");

        jit = new JitAdapter();
        univ3Adapter = new UniV3Adapter(payable(WETH));
        curveAdapter = new CurveStableNGAdapter();
    }

    /// @notice Three real WETH/USDT pools as candidates. JitAdapter dry-runs all three,
    ///         picks the highest-quote winner, and executes the swap for real. We assert
    ///         the core invariant: `realDelta == quotes[winner]` (the post-exec check).
    function test_ForkRP01_three_real_WETH_USDT_pools() public {
        uint256 amountIn = 0.1 ether; // ~$210 — safe for the shallowest pool (Curve SNG)

        // Pre-fund JitAdapter directly with WETH (skip Router for test isolation).
        deal(WETH, address(jit), amountIn);

        // Build three candidates pointing at the three real pools.
        JitAdapter.Candidate[] memory cs = new JitAdapter.Candidate[](3);

        // C0: Uniswap V3 0.01% — adapter handles WETH/USDT swap via uniswapV3SwapCallback.
        //   extraData layout per UniV3Adapter.sellBase: (uint160 sqrtX96, bytes innerData)
        //   inner: (address fromToken, address toToken, uint24 fee)
        //   sqrtX96=0 means use TickMath limit (zeroForOne direction is auto-detected).
        cs[0] = JitAdapter.Candidate({
            adapter: address(univ3Adapter),
            assetTo: address(univ3Adapter),
            rawData: uint256(uint160(UNIV3_POOL)),
            extraData: abi.encode(uint160(0), abi.encode(WETH, USDT, uint24(100)))
        });

        // C1: SushiSwap V3 0.05% — identical wire format to UniV3 (same callback selector).
        cs[1] = JitAdapter.Candidate({
            adapter: address(univ3Adapter),
            assetTo: address(univ3Adapter),
            rawData: uint256(uint160(SUSHI_V3_POOL)),
            extraData: abi.encode(uint160(0), abi.encode(WETH, USDT, uint24(500)))
        });

        // C2: Curve StableNG WETH(i=0) -> USDT(j=1).
        //   extraData layout per CurveStableNGAdapter._curveSwap:
        //   (address fromToken, address toToken, int128 i, int128 j)
        cs[2] = JitAdapter.Candidate({
            adapter: address(curveAdapter),
            assetTo: address(curveAdapter),
            rawData: uint256(uint160(CURVE_SNG_POOL)),
            extraData: abi.encode(WETH, USDT, int128(0), int128(1))
        });

        bytes memory data = abi.encode(WETH, USDT, uint8(0), cs);

        uint256 usdtBefore = IERC20(USDT).balanceOf(user);

        vm.recordLogs();
        (bool ok,) = _callSellBaseWithRefund(data, refundTo);
        require(ok, "JIT sellBase reverted on real pools");

        uint256 realDelta = IERC20(USDT).balanceOf(user) - usdtBefore;

        // Decode JitWinnerSelected event to extract quotes + winner.
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256[] memory quotes;
        uint8 winnerIdx;
        address winnerAdapter;
        bytes32 sig = keccak256("JitWinnerSelected(uint8,uint256[],address)");
        bool found;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(jit) && logs[i].topics[0] == sig) {
                (winnerIdx, quotes, winnerAdapter) =
                    abi.decode(logs[i].data, (uint8, uint256[], address));
                found = true;
                break;
            }
        }
        require(found, "JitWinnerSelected not emitted");

        // --- Report ---
        console2.log("=== JIT Fork Test: three real WETH/USDT pools ===");
        console2.log("Input:                          0.1 WETH");
        console2.log("Quote[0] UniV3 0.01%  (USDT/1e6):", quotes[0]);
        console2.log("Quote[1] SushiV3 0.05% (USDT/1e6):", quotes[1]);
        console2.log("Quote[2] Curve SNG    (USDT/1e6):", quotes[2]);
        console2.log("Winner idx:                     ", winnerIdx);
        console2.log("Winner adapter:                 ", winnerAdapter);
        console2.log("Real-exec delta (USDT/1e6):     ", realDelta);

        // --- Core invariants ---
        // 1. All three real candidates produce a positive quote (sanity).
        assertGt(quotes[0], 0, "UniV3 quote > 0");
        assertGt(quotes[1], 0, "SushiV3 quote > 0");
        assertGt(quotes[2], 0, "Curve quote > 0");

        // 2. THE invariant under audit: dry-run measured quote MUST equal real-exec
        //    delivered delta for the winner. This is JitAdapter's L149 post-exec check
        //    re-asserted from the test side. Failure here would mean the dry-run
        //    sandbox does NOT faithfully predict real-exec output.
        assertEq(realDelta, quotes[winnerIdx], "0-diff: real delta == winner dry-run quote");

        // 3. Winner is genuinely the argmax (defends against a future _findMax regression).
        for (uint256 i = 0; i < quotes.length; i++) {
            assertLe(quotes[i], quotes[winnerIdx], "winner quote must dominate all");
        }
        assertEq(winnerAdapter, cs[winnerIdx].adapter, "winnerAdapter == cs[winner].adapter");

        // 4. JitAdapter must hold no residual fromToken / toToken after the swap.
        //    (Closes the L-1 finding's negative space — verifies no stuck balance in
        //    the production happy path.)
        assertEq(IERC20(WETH).balanceOf(address(jit)), 0, "no WETH leftover on JIT");
        assertEq(IERC20(USDT).balanceOf(address(jit)), 0, "no USDT leftover on JIT");
    }

    // ---------------------------------------------------------------------
    // Calldata helper — mirrors JitTestBase._callSellBaseWithRefund:
    //   appends `ORIGIN_PAYER | refundTo` as the trailing 32 bytes, exactly as
    //   CommonLib._exeAdapter would when invoked by the production Router.
    // ---------------------------------------------------------------------
    function _callSellBaseWithRefund(bytes memory data, address rTo)
        internal
        returns (bool ok, bytes memory ret)
    {
        bytes memory head = abi.encodeWithSelector(IAdapter.sellBase.selector, user, address(jit), data);
        bytes memory payload = abi.encodePacked(head, ORIGIN_PAYER + uint256(uint160(rTo)));
        (ok, ret) = address(jit).call(payload);
    }
}
