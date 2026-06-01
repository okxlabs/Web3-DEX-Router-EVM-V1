pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/TemplateAdapter/UniversalUniswapV3Adapter.sol";

contract HyperEVMIntegrationTest is Test {
    UniversalUniswapV3Adapter public adapter = UniversalUniswapV3Adapter(0x13A325612168e9E9816c69E116C3E1A150273301);
    DexRouter dexRouter = DexRouter(payable(0x9Ac7b1FFEE0f58c0a3c89AA54Afb62efD25DC9fd));

    address payable WHYPE = payable(0x5555555555555555555555555555555555555555); // token0
    address HYPE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // native token
    address LHYPE = 0x5748ae796AE46A4F1348a1693de4b50560485562; // token1
    address tokenApprove = 0x56e6983D59bF472Ced0E63966A14d94A3A291589;
    address pool = 0xD727866efc12da4b80ab3c3f9AeF90eb80026364; // WHYPE/LHYPE fee=100

    address amy = vm.rememberKey(1);

    function setUp() public {
        vm.createSelectFork(vm.envString("HYPEREVM_RPC_URL"));
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

    // =============================================
    // Case 1: HYPE (native) -> LHYPE (ERC20)
    // Tests: native token wrapping + V3 swap + wNativeRelayer
    // =============================================
    function test_HYPEtoLHYPE() public user(amy) {
        uint fromAmount = 1 * 10 ** 16; // 0.01 HYPE
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(HYPE));
        swapInfo.baseRequest.toToken = LHYPE;
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

        // rawData: 0x00 = sellBase (zeroForOne, WHYPE -> LHYPE), weight=10000
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

        // extraData: sqrtPriceLimitX96=0, encode(fromToken, toToken)
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(WHYPE, LHYPE));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(WHYPE)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(address(amy), fromAmount);

        console2.log("HYPE balance before", address(amy).balance);
        console2.log("LHYPE balance before", IERC20(LHYPE).balanceOf(address(amy)));

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

        console2.log("HYPE balance after", address(amy).balance);
        console2.log("LHYPE balance after", IERC20(LHYPE).balanceOf(address(amy)));
    }

    // =============================================
    // Case 2: LHYPE (ERC20) -> HYPE (native)
    // Tests: V3 swap + native token unwrapping via wNativeRelayer
    // =============================================
    function test_LHYPEtoHYPE() public user(amy) {
        uint fromAmount = 1 * 10 ** 16; // 0.01 LHYPE
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(LHYPE));
        swapInfo.baseRequest.toToken = HYPE;
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

        // rawData: 0x80 = sellQuote (oneForZero, LHYPE -> WHYPE), weight=10000
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

        // extraData: sqrtPriceLimitX96=0, encode(fromToken, toToken)
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(LHYPE, WHYPE));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(LHYPE)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(LHYPE, address(amy), fromAmount);
        IERC20(LHYPE).approve(address(tokenApprove), fromAmount);

        console2.log("LHYPE balance before", IERC20(LHYPE).balanceOf(address(amy)));
        console2.log("HYPE balance before", address(amy).balance);

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

        console2.log("LHYPE balance after", IERC20(LHYPE).balanceOf(address(amy)));
        console2.log("HYPE balance after", address(amy).balance);
    }

    // =============================================
    // Case 3: WHYPE (ERC20) -> LHYPE (ERC20)
    // Tests: pure ERC20-to-ERC20 swap without native token handling
    // =============================================
    function test_WHYPEtoLHYPE() public user(amy) {
        uint fromAmount = 1 * 10 ** 16; // 0.01 WHYPE
        SwapInfo memory swapInfo;

        // baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(WHYPE)));
        swapInfo.baseRequest.toToken = LHYPE;
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

        // rawData: 0x00 = sellBase (zeroForOne, WHYPE -> LHYPE), weight=10000
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

        // extraData: sqrtPriceLimitX96=0, encode(fromToken, toToken)
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(uint160(0), abi.encode(WHYPE, LHYPE));

        // fromToken
        swapInfo.batches[0][0].fromToken = uint(uint160(address(WHYPE)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        deal(WHYPE, address(amy), fromAmount);
        IERC20(WHYPE).approve(address(tokenApprove), fromAmount);

        console2.log("WHYPE balance before", IERC20(WHYPE).balanceOf(address(amy)));
        console2.log("LHYPE balance before", IERC20(LHYPE).balanceOf(address(amy)));

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

        console2.log("WHYPE balance after", IERC20(WHYPE).balanceOf(address(amy)));
        console2.log("LHYPE balance after", IERC20(LHYPE).balanceOf(address(amy)));
    }
}
