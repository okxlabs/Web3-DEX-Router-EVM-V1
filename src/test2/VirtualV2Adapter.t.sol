// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/test.sol";
import "@dex/adapter/VirtualsV2Adapter.sol";
import "@dex/DexRouter.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";

//virtuals internal trading
contract VirtualV2Test is Test {

    address bob = vm.rememberKey(1);

    function setUp() public {

    }

    modifier user(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    struct SwapInfo {
        uint256 orderId;
        DexRouter.BaseRequest baseRequest;
        uint256[] batchesAmount;
        DexRouter.RouterPath[][] batches;
        PMMLib.PMMSwapRequest[] extraData;
    }

    function test_virtual_buy() public user(bob) {
        
        DexRouter dexRouter = DexRouter(payable(0x5e2F47bD7D4B357fCfd0Bb224Eb665773B1B9801));
        address tokenApprove = 0x57df6092665eb6058DE53939612413ff4B09114E;

        //swap virtualToken to memeToken
        address BONDING = 0xc3538DdD84619e761b4c03cAf2F785f79889958d;
        address virtualToken = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
        address memeToken = 0xB4411139B1E00C6a9F81C55aEf758227B903b9E2;//name: burn
        address FRouter = 0xBfCE3fbe9cE3a19adb8DbB096Ea2Cb2bb1073F95;

        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 37087045);
        // https://basescan.org/tx/0xa5b69c1bc83a8c7849f3fffc4f051514e45227e22d050706ae03e1081021e05c
        
        VirtualsV2Adapter adapter = new VirtualsV2Adapter(BONDING, virtualToken, FRouter);
        
        deal(virtualToken, bob, 1 * 10 ** 18);
        IERC20(virtualToken).approve(tokenApprove, 1 * 10 ** 18);

        uint256 amount = IERC20(virtualToken).balanceOf(bob);
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(virtualToken)));
        swapInfo.baseRequest.toToken = memeToken;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        // direct interaction with adapter
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(memeToken, true, block.timestamp);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(virtualToken)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        console2.log("virtualToken balance before", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("memeToken balance before", IERC20(memeToken).balanceOf(address(bob)));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("virtualToken balance after", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("memeToken balance after", IERC20(memeToken).balanceOf(address(bob)));
    }

    function test_virtual_sell() public user(bob) {

        DexRouter dexRouter = DexRouter(payable(0x5e2F47bD7D4B357fCfd0Bb224Eb665773B1B9801));
        address tokenApprove = 0x57df6092665eb6058DE53939612413ff4B09114E;

        //swap virtualToken to memeToken
        address BONDING = 0xc3538DdD84619e761b4c03cAf2F785f79889958d;
        address virtualToken = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
        address memeToken = 0xB4411139B1E00C6a9F81C55aEf758227B903b9E2;//name: burn
        address FRouter = 0xBfCE3fbe9cE3a19adb8DbB096Ea2Cb2bb1073F95;

        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 37112672);
        // https://basescan.org/tx/0xe137b4224b72660ba6c60973756ed476dcd63540eba5a3af02b8b6594162dfc9
        
        VirtualsV2Adapter adapter = new VirtualsV2Adapter(BONDING, virtualToken, FRouter);
        
        deal(memeToken, bob, 10 * 10 ** 18);
        IERC20(memeToken).approve(tokenApprove, 10 * 10 ** 18);

        uint256 amount = IERC20(memeToken).balanceOf(bob);
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(memeToken)));
        swapInfo.baseRequest.toToken = virtualToken;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        // direct interaction with adapter
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(memeToken, false, block.timestamp);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(memeToken)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        console2.log("virtualToken balance before", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("memeToken balance before", IERC20(memeToken).balanceOf(address(bob)));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("virtualToken balance after", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("memeToken balance after", IERC20(memeToken).balanceOf(address(bob)));
    }

    function test_virtual_buy_with_refund() public user(bob) {
        
        DexRouter dexRouter = DexRouter(payable(0x5e2F47bD7D4B357fCfd0Bb224Eb665773B1B9801));
        address tokenApprove = 0x57df6092665eb6058DE53939612413ff4B09114E;

        //swap virtualToken to memeToken
        address BONDING = 0xc3538DdD84619e761b4c03cAf2F785f79889958d;
        address virtualToken = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
        address memeToken = 0xB4411139B1E00C6a9F81C55aEf758227B903b9E2;//name: burn
        address FRouter = 0xBfCE3fbe9cE3a19adb8DbB096Ea2Cb2bb1073F95;

        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 37087045);
        
        VirtualsV2Adapter adapter = new VirtualsV2Adapter(BONDING, virtualToken, FRouter);
        
        // Give user virtualToken (same amount as normal test)
        deal(virtualToken, bob, 1 * 10 ** 18);
        IERC20(virtualToken).approve(tokenApprove, 1 * 10 ** 18);

        // KEY: Give adapter extra virtualToken to simulate leftover tokens
        deal(virtualToken, address(adapter), 1 * 10 ** 18);

        console2.log("=== Before Buy Operation with Refund ===");
        console2.log("User VIRTUAL balance before", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("User MEME balance before", IERC20(memeToken).balanceOf(address(bob)));
        console2.log("Adapter VIRTUAL balance before", IERC20(virtualToken).balanceOf(address(adapter)));

        uint256 amount = IERC20(virtualToken).balanceOf(bob);
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(virtualToken)));
        swapInfo.baseRequest.toToken = memeToken;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(memeToken, true, block.timestamp);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(virtualToken)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("=== After Buy Operation with Refund ===");
        console2.log("User VIRTUAL balance after", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("User MEME balance after", IERC20(memeToken).balanceOf(address(bob)));
        console2.log("Adapter VIRTUAL balance after", IERC20(virtualToken).balanceOf(address(adapter)));

        // Verify swap worked correctly
        uint256 memeTokenBalance = IERC20(memeToken).balanceOf(address(bob));
        assertGt(memeTokenBalance, 0, "User should receive MEME_TOKEN");
        
        // Verify adapter has no remaining VIRTUALTOKEN (refund logic should clear it)
        assertEq(IERC20(virtualToken).balanceOf(address(adapter)), 0, "Adapter should have no remaining VIRTUALTOKEN");
    }

    function test_virtual_sell_with_refund() public user(bob) {

        DexRouter dexRouter = DexRouter(payable(0x5e2F47bD7D4B357fCfd0Bb224Eb665773B1B9801));
        address tokenApprove = 0x57df6092665eb6058DE53939612413ff4B09114E;

        //swap memeToken to virtualToken
        address BONDING = 0xc3538DdD84619e761b4c03cAf2F785f79889958d;
        address virtualToken = 0x0b3e328455c4059EEb9e3f84b5543F74E24e7E1b;
        address memeToken = 0xB4411139B1E00C6a9F81C55aEf758227B903b9E2;//name: burn
        address FRouter = 0xBfCE3fbe9cE3a19adb8DbB096Ea2Cb2bb1073F95;

        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 37112672);
        
        VirtualsV2Adapter adapter = new VirtualsV2Adapter(BONDING, virtualToken, FRouter);
        
        // Give user memeToken (same amount as normal test)
        deal(memeToken, bob, 10 * 10 ** 18);
        IERC20(memeToken).approve(tokenApprove, 10 * 10 ** 18);

        // KEY: Give adapter extra memeToken to simulate leftover tokens
        deal(memeToken, address(adapter), 1 * 10 ** 18);

        console2.log("=== Before Sell Operation with Refund ===");
        console2.log("User VIRTUAL balance before", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("User MEME balance before", IERC20(memeToken).balanceOf(address(bob)));
        console2.log("Adapter MEME balance before", IERC20(memeToken).balanceOf(address(adapter)));

        uint256 amount = IERC20(memeToken).balanceOf(bob);
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(memeToken)));
        swapInfo.baseRequest.toToken = virtualToken;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(memeToken, false, block.timestamp);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(memeToken)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("=== After Sell Operation with Refund ===");
        console2.log("User VIRTUAL balance after", IERC20(virtualToken).balanceOf(address(bob)));
        console2.log("User MEME balance after", IERC20(memeToken).balanceOf(address(bob)));
        console2.log("Adapter MEME balance after", IERC20(memeToken).balanceOf(address(adapter)));

        // Verify swap worked correctly
        uint256 virtualTokenBalance = IERC20(virtualToken).balanceOf(address(bob));
        assertGt(virtualTokenBalance, 0, "Should receive VIRTUALTOKEN");
        
        // Verify adapter has no remaining MEME_TOKEN (refund logic should clear it)
        assertEq(IERC20(memeToken).balanceOf(address(adapter)), 0, "Adapter should have no remaining MEME_TOKEN");
    }

}

