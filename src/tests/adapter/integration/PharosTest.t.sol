// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/interfaces/IERC20.sol";
import "@dex/interfaces/IAdapter.sol";

contract PharosTest is Test {
    // Pharos mainnet addresses
    DexRouter dexRouter = DexRouter(payable(0x75f21a97Bd89A9A5683A9f46b5D5B4a080708DEa));
    address constant WPROS = 0x52C48d4213107b20bC583832b0d951FB9CA8F0B0;
    address constant USDC = 0xC879C018dB60520F4355C26eD1a6D572cdAC1815;
    address constant tokenApprove = 0x78466A1488f1883d71cFddd1c621351572dE0a1C;

    // Adapters
    address constant V3_ADAPTER = 0x28bEC908C25D3117328801dc571747F6758A9bE8;
    address constant V4_ADAPTER = 0xfc265D3764140DaB2eb7d038e4151b61e19629b8;

    // Pools
    address constant FAROSWAP_V3_POOL = 0x4146D192Da6428c9e1C243D2A953c625B5765623; // WPROS/USDC fee=3000

    address amy = vm.rememberKey(1);

    struct SwapInfo {
        uint orderId;
        DexRouter.BaseRequest baseRequest;
        uint[] batchesAmount;
        DexRouter.RouterPath[][] batches;
        PMMLib.PMMSwapRequest[] extraData;
    }

    modifier user(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("PHAROS_RPC_URL"));
        console2.log("block", block.number);
    }

    // =============================================
    // V3 Adapter: Direct adapter tests
    // =============================================

    function test_v3_adapter_direct_WPROS_to_USDC() public {
        uint256 amountIn = 0.01 ether;
        deal(WPROS, V3_ADAPTER, amountIn);

        uint256 usdcBefore = IERC20(USDC).balanceOf(address(this));

        bytes memory data = abi.encode(WPROS, USDC);
        bytes memory moreInfo = abi.encode(uint160(0), data);
        IAdapter(V3_ADAPTER).sellBase(address(this), FAROSWAP_V3_POOL, moreInfo);

        uint256 usdcReceived = IERC20(USDC).balanceOf(address(this)) - usdcBefore;
        console2.log("V3 Direct: 0.01 WPROS ->", usdcReceived, "USDC (raw)");
        assertGt(usdcReceived, 0, "Should receive USDC");
    }

    function test_v3_adapter_direct_USDC_to_WPROS() public {
        uint256 amountIn = 1_000_000; // 1 USDC
        deal(USDC, V3_ADAPTER, amountIn);

        uint256 wprosBefore = IERC20(WPROS).balanceOf(address(this));

        bytes memory data = abi.encode(USDC, WPROS);
        bytes memory moreInfo = abi.encode(uint160(0), data);
        IAdapter(V3_ADAPTER).sellQuote(address(this), FAROSWAP_V3_POOL, moreInfo);

        uint256 wprosReceived = IERC20(WPROS).balanceOf(address(this)) - wprosBefore;
        console2.log("V3 Direct: 1 USDC ->", wprosReceived, "WPROS (raw)");
        assertGt(wprosReceived, 0, "Should receive WPROS");
    }

    // =============================================
    // V3 Adapter: DexRouter smartSwap tests
    // =============================================

    function test_dexRouter_v3_WPROS_to_USDC() public user(amy) {
        uint fromAmount = 0.01 ether;
        SwapInfo memory swapInfo;

        swapInfo.baseRequest.fromToken = uint256(uint160(WPROS));
        swapInfo.baseRequest.toToken = USDC;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 1;
        swapInfo.baseRequest.deadLine = block.timestamp + 1000 hours;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);

        // mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = V3_ADAPTER;

        // assetTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = V3_ADAPTER;

        // rawData: direction=0x00 (not reverse), weight=10000, pool address
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(
                    uint8(0x00),
                    uint88(10000),
                    FAROSWAP_V3_POOL
                )
            )
        );

        // extraData: abi.encode(fromToken, toToken) for V3 adapter
        swapInfo.batches[0][0].extraData = new bytes[](1);
        bytes memory innerData = abi.encode(WPROS, USDC);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), innerData);

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(WPROS));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(WPROS, amy, fromAmount);
        IERC20(WPROS).approve(tokenApprove, fromAmount);

        console2.log("DexRouter V3: WPROS->USDC");
        console2.log("USDC before:", IERC20(USDC).balanceOf(amy));
        console2.log("WPROS before:", IERC20(WPROS).balanceOf(amy));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );

        console2.log("USDC after:", IERC20(USDC).balanceOf(amy));
        console2.log("WPROS after:", IERC20(WPROS).balanceOf(amy));
        assertGt(IERC20(USDC).balanceOf(amy), 0, "Should receive USDC");
    }

    function test_dexRouter_v3_USDC_to_WPROS() public user(amy) {
        uint fromAmount = 1_000_000; // 1 USDC
        SwapInfo memory swapInfo;

        swapInfo.baseRequest.fromToken = uint256(uint160(USDC));
        swapInfo.baseRequest.toToken = WPROS;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 1;
        swapInfo.baseRequest.deadLine = block.timestamp + 1000 hours;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);

        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = V3_ADAPTER;

        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = V3_ADAPTER;

        // rawData: direction=0x80 (reverse), weight=10000, pool address
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(
                    uint8(0x80),
                    uint88(10000),
                    FAROSWAP_V3_POOL
                )
            )
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        bytes memory innerData = abi.encode(USDC, WPROS);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), innerData);

        swapInfo.batches[0][0].fromToken = uint(uint160(USDC));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(USDC, amy, fromAmount);
        IERC20(USDC).approve(tokenApprove, fromAmount);

        console2.log("DexRouter V3: USDC->WPROS");
        console2.log("USDC before:", IERC20(USDC).balanceOf(amy));
        console2.log("WPROS before:", IERC20(WPROS).balanceOf(amy));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );

        console2.log("USDC after:", IERC20(USDC).balanceOf(amy));
        console2.log("WPROS after:", IERC20(WPROS).balanceOf(amy));
        assertGt(IERC20(WPROS).balanceOf(amy), 0, "Should receive WPROS");
    }
}
