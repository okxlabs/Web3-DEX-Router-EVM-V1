// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@dex/DexRouter.sol";
import "@dex/adapter/FourMemeAdapter.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";
import {Test, console2} from "forge-std/test.sol";

contract FourMemeTest2 is Test {
    address bob = makeAddr("bob");
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address TOKENMANAGER2 = 0x5c952063c7fc8610FFDB798152D69F0B9550762b;
    address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant _ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 constant FROM_TOKEN_COMMISSION = 0x3ca20afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 constant TO_TOKEN_COMMISSION = 0x3ca20afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 constant FROM_TOKEN_COMMISSION_DUAL = 0x22220afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 constant TO_TOKEN_COMMISSION_DUAL = 0x22220afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 constant _TO_B_COMMISSION_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;

    address refer1 = 0x000000000000000000000000000000000000dEaD;
    address refer2 = 0x000000000000000000000000000000000000bEEF;
    uint256 rate1 = 0.0001 * 10 ** 9;
    uint256 rate2 = (2 * rate1) / 10;
    FourMemeAdapter adapter;

    function setUp() public {
        vm.createSelectFork(vm.envString("BSC_RPC_URL"));
        adapter = new FourMemeAdapter(WBNB, TOKENMANAGER2);
        vm.mockCall(
            address(0xA285353bfd31Fc949D37305D5610D0EF7F378Cf9),
            abi.encodeWithSignature("contains(address)", address(adapter)),
            abi.encode(true)
        );
        vm.label(address(adapter), "adapter");

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

    function test_fourMeme_buy_native_xmode() public user(bob) {
        DexRouter dexRouter = DexRouter(payable(0x6015126d7D23648C2e4466693b8DeaB005ffaba8));
        address tokenApprove = 0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6;

        //swap bnb to memeToken
        address fundToken = WBNB;
        address memeToken = 0x4444c36567758938C18216dA3CFA80e2ee39Efa5; //name: bird2

        //https://bscscan.com/tx/0x95b0cf3dfe37a3fc77bdbbfec8be475b7ede8d4086a58d82fc6d068daac0c8bc

        deal(fundToken, bob, 1 * 10 ** 16);
        IERC20(fundToken).approve(tokenApprove, 1 * 10 ** 16);

        uint256 amount = IERC20(fundToken).balanceOf(bob);
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(fundToken)));
        swapInfo.baseRequest.toToken = memeToken;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        // direct interaction with adapter
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(
            fundToken, memeToken, true, uint256(0), uint256(0), address(0), uint256(0), address(0), uint256(0)
        );
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(fundToken)));

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        console2.log("fundToken balance before", IERC20(fundToken).balanceOf(address(bob)));
        console2.log("memeToken balance before", IERC20(memeToken).balanceOf(address(bob)));

        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        console2.log("fundToken balance after", IERC20(fundToken).balanceOf(address(bob)));
        console2.log("memeToken balance after", IERC20(memeToken).balanceOf(address(bob)));
    }

    // function test_fourMeme_buy() public user(bob) {

    //     DexRouter dexRouter = DexRouter(payable(0x6015126d7D23648C2e4466693b8DeaB005ffaba8));
    //     address tokenApprove = 0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6;

    //     //swap usdt to memeToken
    //     address USDT = 0x55d398326f99059fF775485246999027B3197955;
    //     address fundToken = USDT;
    //     address memeToken = 0xb6A303FAC827B37073C4Fb48Dc3cF25EBe7DF7F1;//name: a

    //     //https://bscscan.com/tx/0x6d302f1a2a71311f1daaec2f4e5ec0731f3a7389cdcf5fb5f34f089d3904ce2b

    //     deal(fundToken, bob, 6 * 10 ** 18);
    //     IERC20(fundToken).approve(tokenApprove, 6 * 10 ** 18);

    //     uint256 amount = IERC20(fundToken).balanceOf(bob);
    //     SwapInfo memory swapInfo;
    //     swapInfo.baseRequest.fromToken = uint256(uint160(address(fundToken)));
    //     swapInfo.baseRequest.toToken = memeToken;
    //     swapInfo.baseRequest.fromTokenAmount = amount;
    //     swapInfo.baseRequest.minReturnAmount = 0;
    //     swapInfo.baseRequest.deadLine = block.timestamp;

    //     swapInfo.batchesAmount = new uint[](1);
    //     swapInfo.batchesAmount[0] = amount;

    //     swapInfo.batches = new DexRouter.RouterPath[][](1);
    //     swapInfo.batches[0] = new DexRouter.RouterPath[](1);
    //     swapInfo.batches[0][0].mixAdapters = new address[](1);
    //     swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
    //     swapInfo.batches[0][0].assetTo = new address[](1);
    //     // direct interaction with adapter
    //     swapInfo.batches[0][0].assetTo[0] = address(adapter);
    //     swapInfo.batches[0][0].rawData = new uint[](1);
    //     swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
    //     swapInfo.batches[0][0].extraData = new bytes[](1);
    //     swapInfo.batches[0][0].extraData[0] = abi.encode(fundToken, memeToken, true, uint256(0), uint256(0), address(0), uint256(0), address(0), uint256(0));
    //     swapInfo.batches[0][0].fromToken = uint256(uint160(address(fundToken)));

    //     swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

    //     console2.log("fundToken balance before", IERC20(fundToken).balanceOf(address(bob)));
    //     console2.log("memeToken balance before", IERC20(memeToken).balanceOf(address(bob)));

    //     dexRouter.smartSwapByOrderId(
    //         swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
    //     );

    //     console2.log("fundToken balance after", IERC20(fundToken).balanceOf(address(bob)));
    //     console2.log("memeToken balance after", IERC20(memeToken).balanceOf(address(bob)));
    // }
}
