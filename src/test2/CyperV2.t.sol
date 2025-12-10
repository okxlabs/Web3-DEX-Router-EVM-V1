pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/DnyFeeAdapter.sol";

contract CyperV2Test is Test {
    DnyFeeAdapter public adapter = DnyFeeAdapter(0x031F1aD10547b8dEB43A36e5491c06A93812023a);
    DexRouter dexRouter = DexRouter(payable(0xF6801D319497789f934ec7F83E142a9536312B08));

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address tokenApprove = 0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f;
    address pool = 0x2574c142F25a0111E73Dbf46C838646759bA1A6E;
    address amy = vm.rememberKey(1);

    function setUp0() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23967899);
    }

    function setUp() public {
        setUp0();
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

    // https://etherscan.io/tx/0x2eb95f67b168eb31642037e686bac6bfc64d4b2e8f5688e8ae3ed9dcdef511e4
    function test_WETHtoUSDT() public user(amy) {
        uint fromAmount = 1 ether;  // 1 WETH
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(WETH));
        swapInfo.baseRequest.toToken = USDT;
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
        swapInfo.batches[0][0].assetTo[0] = address(pool);

        // rawData
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint(
            bytes32(
                abi.encodePacked(
                    uint8(0x00), 
                    uint88(10000), 
                    address(pool)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint256(500));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(WETH));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        // 给 amy WETH 并授权
        deal(WETH, address(amy), fromAmount);
        IERC20(WETH).approve(address(tokenApprove), fromAmount);

        console2.log("WETH balance before", IERC20(WETH).balanceOf(address(amy)));
        console2.log("USDT balance before", IERC20(USDT).balanceOf(address(amy)));

        try dexRouter.smartSwapByOrderId{value: 0}(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        ) {
            console2.log("Swap succeeded");
        } catch Error(string memory reason) {
            console2.log("Swap failed with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("Swap failed with low level error");
            bytes4 selector;
            assembly {
                selector := mload(add(lowLevelData, 32))
            }
            console2.logBytes4(selector);
        }

        bytes memory _data = abi.encodeWithSelector(
            DexRouter.smartSwapByOrderId.selector,
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );

        console2.logBytes(_data);

        console2.log("WETH balance after", IERC20(WETH).balanceOf(address(amy)));
        console2.log("USDT balance after", IERC20(USDT).balanceOf(address(amy)));
    }
}