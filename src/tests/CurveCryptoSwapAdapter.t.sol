// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/adapter/CurveCryptoSwapAdapter.sol";
import "@dex/DexRouter.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";

contract CurveCryptoSwapAdapterTest is Test {  
    address bob = 0x230eD35466dAE1DCFBf83C445561B9f2F7Ef97d2;

    CurveCryptoSwapAdapter adapter;

    DexRouter dexRouter = DexRouter(payable(0xb1E4E25b1938c78Ec0b21cCb2D6a0Be60aA7E63f));
    address tokenApprove = 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4;
    address pool = 0xE080D14bF6eceC4C48eBe11055d4DeA5DbC30e41;
    address USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603; //token0
    address CHOG = 0x350035555E10d9AfAF1566AaebfCeD5BA6C27777; //token1
    
    //https://monadscan.com/tx/0xca2be62fc21e9e14e795d2b503c1c14a49b7b8af96112ae49ecd699dc4d2e940
    function setUp() public {
        vm.createSelectFork(vm.envString("MONAD_RPC_URL"), 38470090);
        adapter = new CurveCryptoSwapAdapter();
        // adapter = CurveStableNGAdapter(payable(0xEcd7Eef15713997528896Cb5db7ec316Db4C2101));
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

    function test_swapUSDCtoCHOG() public user(bob) {
        deal(USDC, bob, 100 * 10 ** 6);
        IERC20(USDC).approve(tokenApprove, 985137);

        uint256 amount = 985137;
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(USDC)));
        swapInfo.baseRequest.toToken = CHOG;
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
        // direct interaction with pool
        swapInfo.batches[0][0].assetTo[0] = address(pool);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(pool))));
        swapInfo.batches[0][0].extraData = new bytes[](1);//extradata is not 0x
        swapInfo.batches[0][0].extraData[0] = abi.encode(USDC, CHOG, uint256(0), uint256(1));
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(USDC)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("USDC balance before", IERC20(USDC).balanceOf(address(bob)));
        console2.log("CHOG balance before", IERC20(CHOG).balanceOf(address(bob)));
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
        console2.log("USDC balance after", IERC20(USDC).balanceOf(address(bob)));
        console2.log("CHOG balance after", IERC20(CHOG).balanceOf(address(bob)));
    }

    function test_swapCHOGtoUSDC() public user(bob) {
        deal(CHOG, bob, 100 * 10 ** 18);
        IERC20(CHOG).approve(tokenApprove, 10 * 10 ** 18);

        uint256 amount = 10 * 10 ** 18;
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(CHOG)));
        swapInfo.baseRequest.toToken = USDC;
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
        // direct interaction with pool
        swapInfo.batches[0][0].assetTo[0] = address(pool);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x80), uint88(10000), address(pool))));
        swapInfo.batches[0][0].extraData = new bytes[](1);//extradata is not 0x
        swapInfo.batches[0][0].extraData[0] = abi.encode(CHOG, USDC, uint256(1), uint256(0));
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(CHOG)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("USDC balance before", IERC20(USDC).balanceOf(address(bob)));
        console2.log("CHOG balance before", IERC20(CHOG).balanceOf(address(bob)));
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("USDC balance after", IERC20(USDC).balanceOf(address(bob)));
        console2.log("CHOG balance after", IERC20(CHOG).balanceOf(address(bob)));
    }
}