pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/DnyFeeAdapter.sol";

contract DnyFeeAdapterTest is Test {
    DnyFeeAdapter public adapter = DnyFeeAdapter(0xfc265D3764140DaB2eb7d038e4151b61e19629b8);
    DexRouter dexRouter = DexRouter(payable(0xb1E4E25b1938c78Ec0b21cCb2D6a0Be60aA7E63f));

    address payable WMON = payable(0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A); // token0
    address MON = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603; // token1
    address tokenApprove = 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4;
    address pool = 0x3fE12728ea1B89E4Bac6e59A9130b61A27D032F8;
    address pancakePool = 0xB33956A3d4057Cb96f8359A5dA979339C2c1D3Ed;
    address MockCake = 0xcf05Fc31A6B693DD0bEB76e958ae4BCD490dc985; // token0
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

    function _test_MockCaketoMockUSDT() public user(amy) {
        uint fromAmount = 1 * 10 ** 16;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(MockCake));
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
        swapInfo.batches[0][0].assetTo[0] = address(pancakePool);

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
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint256(30));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(MockCake)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(MockCake, address(amy), fromAmount);
        IERC20(MockCake).approve(address(tokenApprove), fromAmount);

        console2.log("MockCake balance before", IERC20(MockCake).balanceOf(address(amy)));
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

        console2.log("MockCake balance after", IERC20(MockCake).balanceOf(address(amy)));
        console2.log("MockUSDT balance after", IERC20(MockUSDT).balanceOf(address(amy)));
    }

    function test_MockUSDTtoMockCake() public user(amy) {
        uint fromAmount = 1 * 10 ** 16;
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(MockUSDT));
        swapInfo.baseRequest.toToken = MockCake;

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
    
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(pancakePool);

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
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint256(30));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(MockUSDT)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(MockUSDT, address(amy), fromAmount);
        IERC20(MockUSDT).approve(address(tokenApprove), fromAmount);

        console2.log("MockUSDT balance before", IERC20(MockUSDT).balanceOf(address(amy)));
        console2.log("MockCake balance before", IERC20(MockCake).balanceOf(address(amy)));

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

        console2.log("MockUSDT balance after", IERC20(MockUSDT).balanceOf(address(amy)));
        console2.log("MockCake balance after", IERC20(MockCake).balanceOf(address(amy)));
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
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint256(30));

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
        swapInfo.batches[0][0].assetTo[0] = address(pool);

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
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint256(30));

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