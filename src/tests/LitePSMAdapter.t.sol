pragma solidity 0.8.17;

import "forge-std/console2.sol";
import "forge-std/test.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/LitePSMAdapter.sol";

contract LitePSMAdapterTest is Test {
    LitePSMAdapter adapter;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address DssLitePsm = 0xf6e72Db5454dd049d0788e411b06CfAF16853042;
    address UsdsPsmWrapper = 0xA188EEC8F81263234dA3622A406892F3D630f98c;
    address amy = vm.rememberKey(1);
    address tokenApprove = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
    DexRouter dexRouter = DexRouter(payable(0x5E1f62Dac767b0491e3CE72469C217365D5B48cC));

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        adapter = new LitePSMAdapter();
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

    modifier tokenBalance(address fromToken, uint256 amount) {
        deal(fromToken, amy, amount);
        console2.log("DAI balance before",IERC20(DAI).balanceOf(address(amy)));
        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        _;
        console2.log("DAI balance after",IERC20(DAI).balanceOf(address(amy)));
        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
    }

    function test_swapDAItoUSDC() public user(amy) tokenBalance(DAI, 1 * 10 ** 18){
        uint fromAmount = IERC20(DAI).balanceOf(amy);
        IERC20(DAI).approve(tokenApprove, fromAmount);
        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(DAI));
        swapInfo.baseRequest.toToken = USDC;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        //batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        //mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        //assertTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        //rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(uint8(0x00), uint88(10000), address(DssLitePsm))
            )
        );
        //moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(DAI);
        //fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(DAI)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
    }

    function test_swapUSDCtoDAI() public user(amy) tokenBalance(USDC, 1 * 10 ** 6)
    {
        uint fromAmount = IERC20(USDC).balanceOf(amy);
        IERC20(USDC).approve(tokenApprove, fromAmount);
        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(USDC));
        swapInfo.baseRequest.toToken = DAI;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        //batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        //mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        //assertTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        //rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(uint8(0x80), uint88(10000), address(DssLitePsm))
            )
        );
        //moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(USDC);
        //fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(USDC)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
    }

    function test_swapUSDStoUSDC() public user(amy){
        deal(USDS, amy, 1 * 10 ** 18);
        console2.log("USDS balance before",IERC20(USDS).balanceOf(address(amy)));
        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        uint fromAmount = IERC20(USDS).balanceOf(amy);
        IERC20(USDS).approve(tokenApprove, fromAmount);
        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(USDS));
        swapInfo.baseRequest.toToken = USDC;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        //batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        //mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        //assertTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        //rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(uint8(0x00), uint88(10000), address(UsdsPsmWrapper))
            )
        );
        //moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(USDS);
        //fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(USDS)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
        console2.log("USDS balance after",IERC20(USDS).balanceOf(address(amy)));
        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
    }

    function test_swapUSDCtoUSDS() public user(amy){
        deal(USDC, amy, 1 * 10 ** 6);
        console2.log("USDS balance before",IERC20(USDS).balanceOf(address(amy)));
        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        uint fromAmount = IERC20(USDC).balanceOf(amy);
        IERC20(USDC).approve(tokenApprove, fromAmount);
        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(USDC));
        swapInfo.baseRequest.toToken = USDS;
        swapInfo.baseRequest.fromTokenAmount = fromAmount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = fromAmount;

        //batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        //mixAdapter
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        //assertTo
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        //rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(uint8(0x80), uint88(10000), address(UsdsPsmWrapper))
            )
        );
        //moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(USDC);
        //fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(USDC)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
        console2.log("USDS balance after",IERC20(USDS).balanceOf(address(amy)));
        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
    }
}