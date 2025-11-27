pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/TesseraAdapter.sol";

contract TesseraAdapterTest is Test {
    DexRouter dexRouter = DexRouter(payable(0x2bD541Ab3b704F7d4c9DFf79EfaDeaa85EC034f1));
    TesseraAdapter adapter;
    address WETH = 0x4200000000000000000000000000000000000006;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address tokenApprove = 0x57df6092665eb6058DE53939612413ff4B09114E;
    address amy = vm.rememberKey(1);
    address constant tesseraSwap = 0x55555522005BcAE1c2424D474BfD5ed477749E3e;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        vm.txGasPrice(1 gwei);
        adapter = new TesseraAdapter(tesseraSwap);
    }

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

    // friend -> weth
    function test_WETH2USDC() public user(amy) {
        uint fromAmount = 0.001 ether;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(WETH));
        swapInfo.baseRequest.toToken = USDC;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 1;
        swapInfo.baseRequest.deadLine = block.timestamp + 1000 hours;

        // batchesAmount
        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);

        // mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);

        // assetTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);

        // rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(
                    uint8(0x00), 
                    uint88(10000),
                    address(0)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(WETH, USDC);

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(WETH)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(WETH, address(amy), fromAmount);
        IERC20(WETH).approve(tokenApprove, fromAmount);

        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        console2.log("WETH balance before",IERC20(WETH).balanceOf(address(amy)));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );

        // bytes memory _data = abi.encodeWithSelector(
        //     DexRouter.smartSwapByOrderId.selector,
        //     swapInfo.orderId,
        //     swapInfo.baseRequest,
        //     swapInfo.batchesAmount,
        //     swapInfo.batches,
        //     swapInfo.extraData
        // );
        // console2.logBytes(_data);

        console2.log("WETH balance after",IERC20(WETH).balanceOf(address(amy)));
        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
    }

    // friend -> eth
    function test_USDC2WETH() public user(amy) {
        uint fromAmount = 0.1 * 10 ** 6;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(USDC));
        swapInfo.baseRequest.toToken = WETH;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1000 hours;

        // batchesAmount
        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);

        // mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);

        // assetTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);

        // rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(
                    uint8(0x80), 
                    uint88(10000), 
                    address(0)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(USDC, WETH);

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(USDC)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(USDC, address(amy), fromAmount);
        IERC20(USDC).approve(tokenApprove, fromAmount);

        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        console2.log("WETH balance before",IERC20(WETH).balanceOf(address(amy)));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );

        // bytes memory _data = abi.encodeWithSelector(
        //     DexRouter.smartSwapByOrderId.selector,
        //     swapInfo.orderId,
        //     swapInfo.baseRequest,
        //     swapInfo.batchesAmount,
        //     swapInfo.batches,
        //     swapInfo.extraData
        // );

        // console2.logBytes(_data);

        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
        console2.log("WETH balance after",IERC20(WETH).balanceOf(address(amy)));
    }
}