// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@dex/UniversalRouter.sol";
import "@dex/adapter/OkoswapAdapter.sol";
import "@dex/interfaces/IERC20.sol";
import "@dex/interfaces/IWETH.sol";
import "@dex/libraries/SafeERC20.sol";

contract OkoswapAdapterTest is Test {
    OkoswapAdapter adapter;
    UniversalRouter dexRouter = UniversalRouter(payable(0x69C236E021F5775B0D0328ded5EaC708E3B869DF));
    address token_approve = 0x8b773D83bc66Be128c60e07E17C8901f7a64F000;
    address pool = 0x41F933b2C46E4343CAe58c1f8a024DD7F3a0832F;
    
    address amy = address(0x7189562f0854a4805D36820Ad8a3050D4f8B64F7);
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
    address constant ROUTER = 0x236e11ce039cE0DD079cB356056C9127f65586F9;
    address constant ZhongKui = 0xeAd5dCAdB47AAcc9e051A8c1462d6175BE72DF69;
    address constant OKAY = 0x8854b281Cdf5940Ebd4a753F8D37f49775058e03;
    address constant OKAY_Pool = 0xcAB16B189b71981c0c791c866419A8F1c74E2c41;
    address constant OCAT = 0x2521416e961969893BCE0d4EaC676Fa8eF459595;
    address constant OCAT_Pool = 0xB2a0e042A18dBcBB4aF4a750094dD2f0FF863302;
    address constant OKB = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    modifier user(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"));
        adapter = new OkoswapAdapter(ROUTER, WOKB);
    }

    struct SwapInfo {
        uint orderId;
        UniversalRouter.BaseRequest baseRequest;
        uint[] batchesAmount;
        UniversalRouter.RouterPath[][] batches;
        PMMLib.PMMSwapRequest[] extraData;
    }

    function test_OKB2ZhongKui() public user(amy) {
        address FROM_TOKEN = OKB;
        address TO_TOKEN = ZhongKui;
        uint256 amount = 0.15 ether;

        deal(amy, 0.15 ether);

        SwapInfo memory swapInfo;
 
        swapInfo.baseRequest.fromToken = uint256(uint160(address(OKB)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(pool)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(WOKB, TO_TOKEN);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WOKB)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("OKB balance before", address(amy).balance);
        console2.log("ZhongKui balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        try dexRouter.smartSwapByOrderId{value: amount}(
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

        console2.log("OKB balance after", address(amy).balance);
        console2.log("ZhongKui balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        // Print adapter balances
        console2.log("Adapter OKB balance after", address(adapter).balance);
        console2.log("Adapter ZhongKui balance after", IERC20(TO_TOKEN).balanceOf(address(adapter)));
    }

    function test_ZhongKui2OKB() public user(amy) {
        address FROM_TOKEN = ZhongKui;
        address TO_TOKEN = OKB;
        uint256 amount = 1000000 * 10**18;

        deal(FROM_TOKEN, amy, amount);

        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x80), uint88(10000), address(pool)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(FROM_TOKEN, WOKB);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("OKB balance before", address(amy).balance);
        console2.log("ZhongKui balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("OKB balance after", address(amy).balance);
        console2.log("ZhongKui balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        
        // Print adapter balances
        console2.log("Adapter ZhongKui balance after", IERC20(FROM_TOKEN).balanceOf(address(adapter)));
        console2.log("Adapter OKB balance after", address(adapter).balance);
    }

    function test_OKAY2OCAT() public user(amy) {
        address FROM_TOKEN = OKAY;
        address TO_TOKEN = OCAT;
        uint256 amount = 1000000 * 10**18;

        deal(FROM_TOKEN, amy, amount);

        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x80), uint88(10000), address(OCAT_Pool)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(FROM_TOKEN, TO_TOKEN);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("OKAY balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("OCAT balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("OKAY balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("OCAT balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        // Print adapter balances
        console2.log("Adapter OKAY balance after", IERC20(FROM_TOKEN).balanceOf(address(adapter)));
        console2.log("Adapter OCAT balance after", IERC20(TO_TOKEN).balanceOf(address(adapter)));
    }

    function test_OCAT2OKAY() public user(amy) {
        address FROM_TOKEN = OCAT;
        address TO_TOKEN = OKAY;
        uint256 amount = 1000000 * 10**18;

        deal(FROM_TOKEN, amy, amount);

        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(OCAT_Pool)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(FROM_TOKEN, TO_TOKEN);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("OCAT balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("OKAY balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("OCAT balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("OKAY balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        // Print adapter balances
        console2.log("Adapter OCAT balance after", IERC20(FROM_TOKEN).balanceOf(address(adapter)));
        console2.log("Adapter OKAY balance after", IERC20(TO_TOKEN).balanceOf(address(adapter)));
    }

    function test_OKB2OKAY() public user(amy) {
        address FROM_TOKEN = OKB;
        address TO_TOKEN = OKAY;
        uint256 amount = 0.15 ether;

        deal(amy, 0.15 ether);

        SwapInfo memory swapInfo;
 
        swapInfo.baseRequest.fromToken = uint256(uint160(address(OKB)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x80), uint88(10000), address(OKAY_Pool)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(WOKB, TO_TOKEN);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WOKB)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("OKB balance before", address(amy).balance);
        console2.log("OKAY balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        try dexRouter.smartSwapByOrderId{value: amount}(
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

        console2.log("OKB balance after", address(amy).balance);
        console2.log("OKAY balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        // Print adapter balances
        console2.log("Adapter OKB balance after", address(adapter).balance);
        console2.log("Adapter OKAY balance after", IERC20(TO_TOKEN).balanceOf(address(adapter)));
    }

    function test_OKAY2OKB() public user(amy) {
        address FROM_TOKEN = OKAY;
        address TO_TOKEN = OKB;
        uint256 amount = 1000000 * 10**18;

        deal(FROM_TOKEN, amy, amount);

        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new UniversalRouter.RouterPath[][](1);
        swapInfo.batches[0] = new UniversalRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(OKAY_Pool)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(FROM_TOKEN, WOKB);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("OKB balance before", address(amy).balance);
        console2.log("OKAY balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("OKB balance after", address(amy).balance);
        console2.log("OKAY balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        
        // Print adapter balances
        console2.log("Adapter OKAY balance after", IERC20(FROM_TOKEN).balanceOf(address(adapter)));
        console2.log("Adapter OKB balance after", address(adapter).balance);
    }
}