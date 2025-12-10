pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/adapter/AlgebraAdapter.sol";
import "@dex/DexRouter.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";

contract CyperV4Test is Test {
    DexRouter dexRouter =
        DexRouter(payable(0xF6801D319497789f934ec7F83E142a9536312B08));
    address tokenApprove = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;

    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDC_USDT = 0x7a6179Ed614c65A8e6A3Cf8A611fC93FeD3ba184;

    address arnaud = vm.rememberKey(1);

    AlgebraAdapter adapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23979645);
        adapter = new AlgebraAdapter(payable(WETH)); // local deployed adapter
    }

    modifier user(address _user) {
        vm.startPrank(_user);
        console2.log("User:", _user);
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

    // https://etherscan.io/tx/0xbc1620d68f4c4ffa7c62a93d189645a7c220ba475db57cf9699878399c57dffa
    function test_Cypher_swapUSDC2USDT_dexRouter() public user(arnaud) {
        deal(USDC, arnaud, 1000000);
        IERC20(USDC).approve(tokenApprove, 1000000);

        console2.log(
            "USDC balance before",
            IERC20(USDC).balanceOf(address(arnaud))
        );
        console2.log(
            "USDT balance before",
            IERC20(USDT).balanceOf(address(arnaud))
        );

        uint256 amount = IERC20(USDC).balanceOf(address(arnaud));
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(USDC)));
        swapInfo.baseRequest.toToken = USDT;
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
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(USDC_USDT))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        uint160 sqrtX96 = 0;
        bytes memory data = abi.encode(USDC, USDT);
        swapInfo.batches[0][0].extraData[0] = abi.encode(sqrtX96, data);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(USDC)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );

        console2.log(
            "USDC balance after",
            IERC20(USDC).balanceOf(address(arnaud))
        );  
        console2.log(
            "USDT balance after",
            IERC20(USDT).balanceOf(address(arnaud))
        );
    }
}
