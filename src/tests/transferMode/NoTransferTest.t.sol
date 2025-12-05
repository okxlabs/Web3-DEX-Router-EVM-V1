// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/test.sol";
import "@dex/adapter/FourMemeAdapter.sol";
import "@dex/DexRouter.sol";
import "@dex/TokenApproveProxy.sol";
import "@dex/TokenApprove.sol";
import "@dex/libraries/CommonUtils.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";

contract NoTransferTest is Test {
    // Transfer mode constants
    uint256 internal constant _MODE_NO_TRANSFER = 1 << 251;

    address amy = vm.rememberKey(1);
    DexRouter dexRouter;
    TokenApproveProxy tokenApproveProxy = TokenApproveProxy(0xd99cAE3FAC551f6b6Ba7B9f19bDD316951eeEE98);
    TokenApprove tokenApprove = TokenApprove(0x2c34A2Fb1d0b4f55de51E1d0bDEfaDDce6b7cDD6);
    address tokenApproveProxyAdmin = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;

    address TOKENMANAGER2 = 0x5c952063c7fc8610FFDB798152D69F0B9550762b;
    address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address USDT = 0x55d398326f99059fF775485246999027B3197955;

    function setUp() public {
        vm.createSelectFork("https://bsc-dataseed1.binance.org/");
        dexRouter = new DexRouter();
        vm.startPrank(tokenApproveProxyAdmin);
        tokenApproveProxy.addProxy(address(dexRouter));
        vm.stopPrank();
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

    /// @notice Test NO_TRANSFER mode
    function test_fourMeme_sell_NO_TRANSFER_mode() public  {
        address amy = tx.origin;
        
        vm.startPrank(amy, amy);

        console2.log("=== Testing NO_TRANSFER Mode ===");
        console2.log("address(this): ", address(this));
        console2.log("tx.origin: ", tx.origin);
        console2.log("user: ", amy);
        
        address fundToken = USDT;
        address memeToken = 0xb6A303FAC827B37073C4Fb48Dc3cF25EBe7DF7F1; //name: a

        FourMemeAdapter.TradeInfo memory tradeInfo;
        tradeInfo.fundAddress = fundToken;
        tradeInfo.tokenAddress = memeToken;
        tradeInfo.buyMeme = false;
        tradeInfo.sellMemeAmount = 1550234 * 10 ** 18;
        tradeInfo.sellCommissionRate1 = 100;
        tradeInfo.sellCommissionRate2 = 100;
        tradeInfo.sellCommissionReceiver1 = vm.rememberKey(1111);
        tradeInfo.sellCommissionReceiver2 = vm.rememberKey(2222);
        tradeInfo.minReturnAmount = 0;
        
        FourMemeAdapter adapter = new FourMemeAdapter(WBNB, TOKENMANAGER2);
        
        deal(memeToken, amy, 1550234 * 10 ** 18);
        IERC20(memeToken).approve(TOKENMANAGER2, 1550234 * 10 ** 18);

        uint256 amount = IERC20(memeToken).balanceOf(amy);
        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(memeToken)));
        swapInfo.baseRequest.toToken = fundToken;
        swapInfo.baseRequest.fromTokenAmount = 1550234 * 10 ** 18;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = 1550234 * 10 ** 18;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(tradeInfo);
        // Key: RouterPath fromToken uses _MODE_NO_TRANSFER flag
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(memeToken))) | _MODE_NO_TRANSFER;

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        uint256 fundTokenBefore = IERC20(fundToken).balanceOf(address(amy));
        uint256 memeTokenBefore = IERC20(memeToken).balanceOf(address(amy));

        console2.log("fundToken balance before", fundTokenBefore);
        console2.log("memeToken balance before", memeTokenBefore);
        
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        uint256 fundTokenAfter = IERC20(fundToken).balanceOf(address(amy));
        uint256 memeTokenAfter = IERC20(memeToken).balanceOf(address(amy));

        console2.log("fundToken balance after", fundTokenAfter);
        console2.log("memeToken balance after", memeTokenAfter);
        console2.log("commissionReceiver1 fundToken balance", IERC20(fundToken).balanceOf(tradeInfo.sellCommissionReceiver1));
        console2.log("commissionReceiver2 fundToken balance", IERC20(fundToken).balanceOf(tradeInfo.sellCommissionReceiver2));

        // Verify successful transaction
        assert(memeTokenAfter == 0); // All meme tokens sold
        assert(fundTokenAfter > fundTokenBefore); // Received fund tokens
        
        // Verify correct commission distribution
        uint256 expectedCommission = 59405928549929294; // From test results
        assertEq(IERC20(fundToken).balanceOf(tradeInfo.sellCommissionReceiver1), expectedCommission);
        assertEq(IERC20(fundToken).balanceOf(tradeInfo.sellCommissionReceiver2), expectedCommission);

        vm.stopPrank();
    }

    /// @notice Test legacy mode - Expected to fail due to access restrictions
    /// @dev This test shows why FourMeme launchpad projects need NO_TRANSFER mode
    function test_fourMeme_sell_legacy_mode_should_fail() public  {
        address amy = tx.origin;
        
        vm.startPrank(amy, amy);

        console2.log("=== Testing Legacy Mode (Expected Failure) ===");
        console2.log("address(this): ", address(this));
        console2.log("tx.origin: ", tx.origin);
        console2.log("user: ", amy);
        
        address fundToken = USDT;
        address memeToken = 0xb6A303FAC827B37073C4Fb48Dc3cF25EBe7DF7F1; //name: a

        FourMemeAdapter.TradeInfo memory tradeInfo;
        tradeInfo.fundAddress = fundToken;
        tradeInfo.tokenAddress = memeToken;
        tradeInfo.buyMeme = false;
        tradeInfo.sellMemeAmount = 1550234 * 10 ** 18;
        tradeInfo.sellCommissionRate1 = 100;
        tradeInfo.sellCommissionRate2 = 100;
        tradeInfo.sellCommissionReceiver1 = vm.rememberKey(1111);
        tradeInfo.sellCommissionReceiver2 = vm.rememberKey(2222);
        tradeInfo.minReturnAmount = 0;
        
        FourMemeAdapter adapter = new FourMemeAdapter(WBNB, TOKENMANAGER2);
        
        deal(memeToken, amy, 1550234 * 10 ** 18);
        IERC20(memeToken).approve(TOKENMANAGER2, 1550234 * 10 ** 18);

        SwapInfo memory swapInfo;
        swapInfo.baseRequest.fromToken = uint256(uint160(address(memeToken)));
        swapInfo.baseRequest.toToken = fundToken;
        swapInfo.baseRequest.fromTokenAmount = 1550234 * 10 ** 18;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        swapInfo.batchesAmount = new uint[](1);
        swapInfo.batchesAmount[0] = 1550234 * 10 ** 18;

        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter);
        swapInfo.batches[0][0].rawData = new uint[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(tradeInfo);
        // RouterPath fromToken no _MODE_NO_TRANSFER flag
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(memeToken))); // Note: no | _MODE_NO_TRANSFER

        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        console2.log("fundToken balance before", IERC20(fundToken).balanceOf(address(amy)));
        console2.log("memeToken balance before", IERC20(memeToken).balanceOf(address(amy)));

        // Expected to fail here because legacy mode tries claimTokens through TokenApproveProxy
        vm.expectRevert("TokenApprove: Access restricted");
        dexRouter.smartSwapByOrderId(
            swapInfo.orderId, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );

        vm.stopPrank();
    }
}
