pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/TemplateAdapter/UniversalUniswapV3Adapter.sol";

contract UniversalUniswapV3AdapterTest is Test {
    UniversalUniswapV3Adapter public adapter = UniversalUniswapV3Adapter(0xd22caC235c9D2A8252b0e02985a6C67a959b21b0);
    DexRouter dexRouter = DexRouter(payable(0xb1E4E25b1938c78Ec0b21cCb2D6a0Be60aA7E63f));

    address payable WMON = payable(0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A); // token0
    address MON = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603; // token1
    address tokenApprove = 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4;
    address pool = 0x659bD0BC4167BA25c62E05656F78043E7eD4a9da;
    address pancakePool = 0x3A8935B0225D1Bdfacc009902943BcBa2AeCd3dB;
    address MockUSDT = 0xF05266b1B1759D3A2746cd3b031b802C2496b278; // token1
    address amy = vm.rememberKey(1);

    function setUp0() public {
        vm.createSelectFork(vm.envString("MONAD_RPC_URL"));
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

    function _test_MockUSDTtoUSDC() public user(amy) {
        uint fromAmount = 1 * 10 ** 16;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(MockUSDT));
        swapInfo.baseRequest.toToken = USDC;
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
                    address(pancakePool)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(MockUSDT, USDC, uint24(3000)));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(MockUSDT)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(MockUSDT, address(amy), fromAmount);
        IERC20(MockUSDT).approve(address(tokenApprove), fromAmount);

        console2.log("MockUSDT balance before",IERC20(MockUSDT).balanceOf(address(amy)));
        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));

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

        console2.log("MockUSDT balance after",IERC20(MockUSDT).balanceOf(address(amy)));
        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
    }

    function test_USDCtoMockUSDT() public user(amy) {
        uint fromAmount = 1 * 10 ** 4;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(USDC));
        swapInfo.baseRequest.toToken = MockUSDT;
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
                    uint8(0x00), 
                    uint88(10000), 
                    address(pancakePool)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(USDC, MockUSDT, uint24(3000)));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(USDC)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(USDC, address(amy), fromAmount);
        IERC20(USDC).approve(address(tokenApprove), fromAmount);

        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        console2.log("MockUSDT balance before",IERC20(MockUSDT).balanceOf(address(amy)));

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

        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
        console2.log("MockUSDT balance after",IERC20(MockUSDT).balanceOf(address(amy)));
    }

    function _test_MONtoUSDC() public user(amy) {
        uint fromAmount = 1 * 10 ** 16;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(MON));
        swapInfo.baseRequest.toToken = USDC;
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
                    uint8(0x00), 
                    uint88(10000), 
                    address(pool)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(WMON, USDC, uint24(3000)));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(WMON)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(address(amy), fromAmount);

        console2.log("MON balance before", address(amy).balance);
        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));

        try dexRouter.smartSwapByOrderId{value: fromAmount}(
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

        console2.log("MON balance after", address(amy).balance);
        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
    }

    function _test_USDCtoMON() public user(amy) {
        uint fromAmount = 1 * 10 ** 4;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(USDC));
        swapInfo.baseRequest.toToken = MON;
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
                    address(pool)
                )
            )
        );

        // moreInfo
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(USDC, WMON, uint24(3000)));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(USDC)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(USDC, address(amy), fromAmount);
        IERC20(USDC).approve(address(tokenApprove), fromAmount);

        console2.log("USDC balance before",IERC20(USDC).balanceOf(address(amy)));
        console2.log("MON balance before", address(amy).balance);

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

        console2.log("USDC balance after",IERC20(USDC).balanceOf(address(amy)));
        console2.log("MON balance after", address(amy).balance);
    }
}