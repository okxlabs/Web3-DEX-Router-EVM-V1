// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "forge-std/test.sol";
import "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import "@dex/adapter/UniV4Adapter.sol";
import "@dex/interfaces/IHooks.sol";

contract UniV4Test is Test {
    /// @notice Returns the key for identifying a pool
    struct PoolKey {
        /// @notice The lower currency of the pool, sorted numerically
        Currency currency0;
        /// @notice The higher currency of the pool, sorted numerically
        Currency currency1;
        /// @notice The pool LP fee, capped at 1_000_000. If the highest bit is 1, the pool has a dynamic fee and must be exactly equal to 0x800000
        uint24 fee;
        /// @notice Ticks that involve positions must be a multiple of tick spacing
        int24 tickSpacing;
        /// @notice The hooks of the pool
        IHooks hooks;
    }
    //https://dashboard.tenderly.co/tx/mainnet/0xde840c27b431f80bc18bf42bab7c212bd4f2c36c7b6aa2aa7e2c9ef984587854/debugger?trace=0.3.0.0.0.0.1.1.0
    type Currency is address;
    //DexRouter dexRouter = DexRouter(payable(0x3b3ae790Df4F312e745D270119c6052904FB6790));
    DexRouter dexRouter = DexRouter(payable(0x6b2C0c7be2048Daa9b5527982C29f48062B34D58));
    address token_approve = 0x57df6092665eb6058DE53939612413ff4B09114E;
    address poolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; //8
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    //address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address WETH = 0x4200000000000000000000000000000000000006;
    address PERP = 0xbC396689893D065F41bc2C6EcbeE5e0085233447; //18
    address RUG = 0x4eca3006bcb1D7cb624c6d17D0a1d7FaDa65Ab36;
    address PENDLE = 0x808507121B80c02388fAd14726482e061B8da827;
    address RAIZ = 0xD5A3Ac5f6ee7948d0403a8154CdC0c76B0945Cf7;
    address OIKIOS = 0x6E7F11641c1EC71591828E531334192d622703F7;
    address TONCOIN = 0x582d872A1B094FC48F5DE31D3B73F2D9bE47def1;
    address G = 0x9C7BEBa8F6eF6643aBd725e45a4E8387eF260649;
    address cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf; //8
    address LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1; //8
    address USD = 0xB79DD08EA68A908A97220C76d19A6aA9cBDE4376; //6
    
    // Monad addresses
    address MON = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address USDC_monad = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    
    //address user = 0xcBfd32FDec86F88784266221CcE8141dA7B9A9eD;
    address amy = vm.rememberKey(1);
    UniV4Adapter adapter;

    modifier user(address _user) {
        vm.startPrank(_user);
        _;
        vm.stopPrank();
    }

    function setUp() public {
        //vm.createSelectFork("https://eth1.lava.build");
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        adapter = new UniV4Adapter(poolManager, WETH);
    }
    
    struct SwapInfo {
        uint orderId;
        DexRouter.BaseRequest baseRequest;
        uint[] batchesAmount;
        DexRouter.RouterPath[][] batches;
        PMMLib.PMMSwapRequest[] extraData;
    }

    function test_USD2ETH() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = USD;
        address TO_TOKEN = ETH;
        uint24 fee = 100;
        int24 tickSpacing = 1;
        uint256 amount = 30000000;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(0), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("ETH balance before", address(amy).balance);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("ETH balance after", address(amy).balance);
        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
    }

    function test_ETH2USD() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = ETH;
        address TO_TOKEN = USD;
        uint24 fee = 100;
        int24 tickSpacing = 1;
        uint256 amount = 15000000000000000;

        deal(amy, amount);
        //SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(ETH))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(0), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WETH))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("ETH balance before", address(amy).balance);
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("ETH balance after", address(amy).balance);
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_cbBTC2LBTC() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = cbBTC;
        address TO_TOKEN = LBTC;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1 * 10 ** 8;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_LBTC2cbBTC() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = LBTC;
        address TO_TOKEN = cbBTC;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 0.01 * 10 ** 18;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_USDC2G() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = USDC;
        address TO_TOKEN = G;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1.88 * 10 ** 6;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }
        
    function _test_G() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = G;
        address TO_TOKEN = USDC;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 111 * 10 ** 18;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_ETH2TONCOIN() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = ETH;
        address TO_TOKEN = TONCOIN;
        uint24 fee = 10000;
        int24 tickSpacing = 200;
        uint256 amount = 15000000000000000;

        deal(amy, amount);
        //SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(ETH))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(0), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WETH))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("ETH balance before", address(amy).balance);
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("ETH balance after", address(amy).balance);
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }
    
    function _test_USDT() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = USDT;
        address TO_TOKEN = OIKIOS;
        uint24 fee = 200000;
        int24 tickSpacing = 4000;
        uint256 amount = 100000000;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_ETH2RAIZ() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = ETH;
        address TO_TOKEN = RAIZ;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 15000000000000000;

        deal(amy, amount);
        //SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(ETH))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(0), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WETH))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("ETH balance before", address(amy).balance);
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("ETH balance after", address(amy).balance);
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_PENDLE2USDT() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = PENDLE;
        address TO_TOKEN = USDT;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 49423424370000000000000;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_ETH2RUG() public user(amy){
        //poolId: 0xf3a3174c3471b6963493b56e76e6c744fc49af76aadbbf1d4a1062d53b5f5cb2
        address FROM_TOKEN = ETH;
        address TO_TOKEN = RUG;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 5200000000000000;

        deal(amy, amount);
        //SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(ETH))); //
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(0), address(TO_TOKEN), fee, tickSpacing); //

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WETH))); //
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("ETH balance before", address(amy).balance);
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("ETH balance after", address(amy).balance);
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_ETH2PERP() public user(amy){
        //poolId: 0x3ea74c37fbb79dfcd6d760870f0f4e00cf4c3960b3259d0d43f211c0547394c1
        address FROM_TOKEN = ETH;
        address TO_TOKEN = PERP;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1115317071575630536;

        deal(amy, amount);
        //SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(ETH)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(0), address(TO_TOKEN), fee, tickSpacing);

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WETH)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("ETH balance before", address(amy).balance);
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("ETH balance after", address(amy).balance);
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_WBTC2USDC_refund() public user(amy){
        //poolId: 0x3ea74c37fbb79dfcd6d760870f0f4e00cf4c3960b3259d0d43f211c0547394c1
        address FROM_TOKEN = WBTC;
        address TO_TOKEN = USDC;
        uint256 amount = 111300826;
        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), uint24(500), int24(10));

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
        try dexRouter.smartSwapByOrderId(
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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_USDT2ETH() public user(amy){
        deal(USDT, amy, 5201837);
        uint256 amount = 5000000;
        SafeERC20.safeApprove(IERC20(USDT), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(USDT)));
        swapInfo.baseRequest.toToken = ETH;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        // PoolKey memory key = PoolKey({
        //     currency0: Currency.wrap(address(0)),
        //     currency1: Currency.wrap(USDT),
        //     fee: 500,
        //     tickSpacing: 10,
        //     hooks: IHooks(address(0))
        // });

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(USDT), address(0), uint24(500), int24(10));

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(USDT)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        console2.log("USDT balance before", IERC20(USDT).balanceOf(address(amy)));
        console2.log("ETH balance before", address(amy).balance);
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
        console2.log("USDT balance after", IERC20(USDT).balanceOf(address(amy)));
        console2.log("ETH balance after", address(amy).balance);
    }

    function _test_ETH2USDT() public user(amy){
        deal(amy, 39977501711779046);
        uint amount = 30000000000000000;
        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(ETH)));
        swapInfo.baseRequest.toToken = USDT;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        // PoolKey memory key = PoolKey({
        //     currency0: Currency.wrap(address(0)),
        //     currency1: Currency.wrap(USDT),
        //     fee: 500,
        //     tickSpacing: 10,
        //     hooks: IHooks(address(0))
        // });

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(0), address(USDT), uint24(500), int24(10));

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WETH)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("USDT balance before", IERC20(USDT).balanceOf(address(amy)));
        console2.log("ETH balance before", address(amy).balance);
        dexRouter.smartSwapByOrderId{value: 30000000000000000}(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
        console2.log("USDT balance after", IERC20(USDT).balanceOf(address(amy)));
        console2.log("ETH balance after", address(amy).balance);
    }

    function _test_USDe2USDT() public user(amy){
        uint amount = 1 ether;
        deal(USDe, amy, amount);
        SafeERC20.safeApprove(IERC20(USDe), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(USDe)));
        swapInfo.baseRequest.toToken = USDT;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        // PoolKey memory key = PoolKey({
        //     currency0: Currency.wrap(USDe),
        //     currency1: Currency.wrap(USDT),
        //     fee: 100,
        //     tickSpacing: 1,
        //     hooks: IHooks(address(0))
        // });

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(USDe), address(USDT), uint24(100), int24(1));

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(USDe)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("USDT balance before", IERC20(USDT).balanceOf(address(amy)));
        console2.log("USDe balance before", IERC20(USDe).balanceOf(address(amy)));
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
        console2.log("USDT balance after", IERC20(USDT).balanceOf(address(amy)));
        console2.log("USDe balance after", IERC20(USDe).balanceOf(address(amy)));
    }

    function _test_USDT2USDe() public user(amy){
        uint amount = 1 * 10 ** 6;
        deal(USDT, amy, amount);
        SafeERC20.safeApprove(IERC20(USDT), token_approve, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(USDT)));
        swapInfo.baseRequest.toToken = USDe;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);

        // PoolKey memory key = PoolKey({
        //     currency0: Currency.wrap(USDe),
        //     currency1: Currency.wrap(USDT),
        //     fee: 100,
        //     tickSpacing: 1,
        //     hooks: IHooks(address(0))
        // });

        swapInfo.batches[0][0].extraData[0] = abi.encode(address(USDT), address(USDe), uint24(100), int24(1));

        swapInfo.batches[0][0].fromToken = uint256(uint160(address(USDT)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("USDT balance before", IERC20(USDT).balanceOf(address(amy)));
        console2.log("USDe balance before", IERC20(USDe).balanceOf(address(amy)));
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId,
            swapInfo.baseRequest,
            swapInfo.batchesAmount,
            swapInfo.batches,
            swapInfo.extraData
        );
        console2.log("USDT balance after", IERC20(USDT).balanceOf(address(amy)));
        console2.log("USDe balance after", IERC20(USDe).balanceOf(address(amy)));
    }

    // ===== Monad Tests =====
    // NOTE: These tests require MONAD_RPC_URL to be set and Monad-specific setup
    
    function _test_monad_WMON2USDC() public user(amy){
        //poolId: 0x0f59a6494b686ccfba956980abf60c2ef0f4ead0ee9a85b1e3f03905afc79ba5
        address FROM_TOKEN = WMON;
        address TO_TOKEN = USDC_monad;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1 * 10 ** 10;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        console2.log("WMON balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("USDC balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("WMON balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("USDC balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_monad_MON2USDC() public user(amy){
        //poolId: 0x0f59a6494b686ccfba956980abf60c2ef0f4ead0ee9a85b1e3f03905afc79ba5
        address TO_TOKEN = USDC_monad;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1 * 10 ** 10;

        deal(amy, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(MON)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(address(WMON), address(TO_TOKEN), fee, tickSpacing);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(WMON)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("MON balance before", address(amy).balance);
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));
        
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

        console2.log("MON balance after", address(amy).balance);
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_monad_USDC2WMON() public user(amy){
        //poolId: 0x0f59a6494b686ccfba956980abf60c2ef0f4ead0ee9a85b1e3f03905afc79ba5
        address FROM_TOKEN = USDC_monad;
        address TO_TOKEN = WMON;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1 * 10 ** 4;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(TO_TOKEN), fee, tickSpacing);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", IERC20(TO_TOKEN).balanceOf(address(amy)));

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", IERC20(TO_TOKEN).balanceOf(address(amy)));
    }

    function _test_monad_USDC2MON() public user(amy){
        //poolId: 0x0f59a6494b686ccfba956980abf60c2ef0f4ead0ee9a85b1e3f03905afc79ba5
        address FROM_TOKEN = USDC_monad;
        address TO_TOKEN = MON;
        uint24 fee = 3000;
        int24 tickSpacing = 60;
        uint256 amount = 1 * 10 ** 4;

        deal(FROM_TOKEN, amy, amount);
        SafeERC20.safeApprove(IERC20(FROM_TOKEN), 0xf534A8a1CAD0543Cd6438f7534CA3486c01998d4, amount);

        SwapInfo memory swapInfo;

        //baseRequest
        swapInfo.baseRequest.fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.baseRequest.toToken = TO_TOKEN;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp + 1000 hours;

        //batchsAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0)))
        );

        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(address(FROM_TOKEN), address(WMON), fee, tickSpacing);
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(FROM_TOKEN)));
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);
        
        console2.log("FROM_TOKEN balance before", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance before", address(amy).balance);

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

        console2.log("FROM_TOKEN balance after", IERC20(FROM_TOKEN).balanceOf(address(amy)));
        console2.log("TO_TOKEN balance after", address(amy).balance);
    }
}