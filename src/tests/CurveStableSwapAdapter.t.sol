// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/adapter/CurveStableSwapAdapter.sol";
import "@dex/DexRouter.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";

contract CurveStableSwapAdapterTest is Test {  
    address bob = vm.rememberKey(1);

    CurveStableSwapAdapter adapter;

    DexRouter dexRouter = DexRouter(payable(0xb1E4E25b1938c78Ec0b21cCb2D6a0Be60aA7E63f));
    address tokenApprove = 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4;
    address pool = 0x2D84D79C852f6842AbE0304b70bBaA1506AdD457;
    address AZND = 0x4917a5ec9fCb5e10f47CBB197aBe6aB63be81fE8; //token0
    address AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a; //token1

    function setUp() public {
        vm.createSelectFork(vm.envString("MONAD_RPC_URL"));
        adapter = new CurveStableSwapAdapter();
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

    function test_swapAZNDtoAUSD() public user(bob) {
        deal(AZND, bob, 0.001 * 10 ** 18);
        IERC20(AZND).approve(tokenApprove, 0.001 * 10 ** 18);

        uint256 amount = 0.001 * 10 ** 18;
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(AZND)));
        swapInfo.baseRequest.toToken = AUSD;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1000 hours;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(pool))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(AZND, AUSD, int128(0), int128(1), false);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(AZND)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("AZND balance before", IERC20(AZND).balanceOf(address(bob)));
        console2.log("AUSD balance before", IERC20(AUSD).balanceOf(address(bob)));
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("AZND balance after", IERC20(AZND).balanceOf(address(bob)));
        console2.log("AUSD balance after", IERC20(AUSD).balanceOf(address(bob)));
    }
}