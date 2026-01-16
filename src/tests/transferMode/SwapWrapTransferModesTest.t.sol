// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "../common/Permit2Helper.t.sol";
import "@dex/interfaces/permit2/IPermit2.sol";
import "@dex/interfaces/permit2/ISignatureTransfer.sol";
import "@dex/interfaces/IDexRouter.sol";
import "forge-std/console.sol";

/**
 * @title SwapWrapTest
 * @notice Test swapWrap and swapWrapToWithBaseRequest with different transfer modes
 * @dev Tests ETH <-> WETH swaps with LEGACY, DIRECT, PERMIT2_ALLOWANCE, and PERMIT2_SIGNATURE modes
 */
contract SwapWrapTransferModesTest is TrimAndCommissionTestBase {
    uint256 constant SWAP_AMOUNT = 1 ether;
    uint256 constant REVERSE_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    
    uint256 public alicePrivateKey = 0xa11ce;
    address public alice = vm.addr(alicePrivateKey);
    
    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        tokenApprove = TokenApprove(0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f);
        tokenApproveProxy = TokenApproveProxy(0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58);
        wNativeRelayer = WNativeRelayer(payable(0x5703B683c7F928b721CA95Da988d73a3299d4757));
        permit2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
        
        dexRouter = new DexRouter(admin);
    
        if (address(dexRouter).balance > 0) {
            vm.deal(address(dexRouter), 0);
        }
        
        vm.startPrank(0xAcE2B3E7c752d5deBca72210141d464371b3B9b1);
        tokenApproveProxy.addProxy(address(dexRouter));
        address[] memory whitelistedCallers = new address[](1);
        whitelistedCallers[0] = address(dexRouter);
        wNativeRelayer.setCallerOk(whitelistedCallers, true);
        vm.stopPrank();
        
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        
        vm.startPrank(alice);
        IWETH(WETH).deposit{value: 5 ether}();
        vm.stopPrank();
        
        vm.startPrank(bob);
        IWETH(WETH).deposit{value: 5 ether}();
        vm.stopPrank();
    }

    // ============================================
    // Test swapWrap function (rawdata encoding)
    // ============================================

    /// @notice Test ETH -> WETH with LEGACY mode
    function test_swapWrap_ETH_to_WETH_Legacy() public {
        uint256 orderId = 12345;
        uint256 rawdata = SWAP_AMOUNT; // mode = 0 (LEGACY), reversed = false
        
        vm.startPrank(alice);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        uint256 routerEthBefore = address(dexRouter).balance;
        
        dexRouter.swapWrap{value: SWAP_AMOUNT}(orderId, rawdata);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        uint256 ethAfter = alice.balance;
        uint256 routerEthAfter = address(dexRouter).balance;
        
        console.log("DexRouter ETH balance after swap:", routerEthAfter);
        console.log("ETH left in DexRouter:", routerEthAfter);
        console.log("Alice received WETH:", wethAfter - wethBefore);
        
        assertEq(wethAfter - wethBefore, SWAP_AMOUNT, "WETH balance should increase by SWAP_AMOUNT");
        assertEq(ethBefore - ethAfter, SWAP_AMOUNT, "ETH balance should decrease by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with LEGACY mode
    function test_swapWrap_WETH_to_ETH_Legacy() public {
        uint256 orderId = 12346;
        uint256 rawdata = REVERSE_MASK | SWAP_AMOUNT; // mode = 0 (LEGACY), reversed = true
        
        vm.startPrank(alice);
        
        // Approve WETH to ApproveProxy
        IERC20(WETH).approve(address(tokenApprove), type(uint256).max);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        // Check DexRouter's ETH balance before swap
        uint256 routerEthBefore = address(dexRouter).balance;
        console.log("DexRouter ETH balance before swap:", routerEthBefore);
        console.log("Alice ETH balance before swap:", ethBefore);
        
        dexRouter.swapWrap(orderId, rawdata);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        uint256 ethAfter = alice.balance;
        uint256 routerEthAfter = address(dexRouter).balance;
        
        console.log("DexRouter ETH balance after swap:", routerEthAfter);
        console.log("Alice ETH balance after swap:", ethAfter);
        console.log("Alice received ETH:", ethAfter - ethBefore);
        console.log("Expected ETH:", SWAP_AMOUNT);
        console.log("Extra ETH received:", (ethAfter - ethBefore) - SWAP_AMOUNT);
        
        assertEq(wethBefore - wethAfter, SWAP_AMOUNT, "WETH balance should decrease by SWAP_AMOUNT");
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test ETH -> WETH with PERMIT2_ALLOWANCE mode (N/A - ETH cannot use Permit2)
    /// ETH -> WETH always uses msg.value, so PERMIT2_ALLOWANCE doesn't apply
    
    /// @notice Test WETH -> ETH with PERMIT2_ALLOWANCE mode
    function test_swapWrap_WETH_to_ETH_Permit2Allowance() public {
        uint256 orderId = 12347;
        uint256 rawdata = REVERSE_MASK | _MODE_PERMIT2_ALLOWANCE | SWAP_AMOUNT;
        
        vm.startPrank(alice);
        
        // Approve WETH to Permit2
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        IPermit2Approve(address(permit2)).approve(WETH, address(dexRouter), type(uint160).max, type(uint48).max);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        dexRouter.swapWrap(orderId, rawdata);

        bytes memory data = abi.encodeWithSelector(dexRouter.swapWrap.selector, orderId, rawdata);
        // console.logBytes(data);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        uint256 ethAfter = alice.balance;
        
        assertEq(wethBefore - wethAfter, SWAP_AMOUNT, "WETH balance should decrease by SWAP_AMOUNT");
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with PERMIT2_SIGNATURE mode
    function test_swapWrap_WETH_to_ETH_Permit2Signature() public {
        uint256 orderId = 12348;
        uint256 rawdata = REVERSE_MASK | _MODE_PERMIT2_SIGNATURE | SWAP_AMOUNT;
        
        // Generate Permit2 signature
        uint256 nonce = 0;
        uint48 deadline = uint48(block.timestamp + 1000);
        
        // Use batch transfer with single amount
        uint256[] memory maxAmounts = new uint256[](1);
        maxAmounts[0] = SWAP_AMOUNT;
        
        ISignatureTransfer.PermitBatchTransferFrom memory permit = getPermitBatchTransferFrom(
            WETH,
            maxAmounts,
            nonce,
            deadline
        );
        
        bytes memory signature = getPermitBatchTransferSignature(
            permit,
            alicePrivateKey,
            address(dexRouter),
            Permit2EthDomainSeperator
        );
        
        bytes memory permit2Data = _buildPermit2InfoUnified(maxAmounts, nonce, deadline, alice, signature);
        
        vm.startPrank(alice);
        
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        bytes memory data = abi.encodeWithSelector(dexRouter.swapWrap.selector, orderId, rawdata);
        data = bytes.concat(data, permit2Data);
        // console.logBytes(data);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "swapWrap call failed");
        
        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        uint256 ethAfter = alice.balance;
        
        assertEq(wethBefore - wethAfter, SWAP_AMOUNT, "WETH balance should decrease by SWAP_AMOUNT");
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with DIRECT mode
    function test_swapWrap_WETH_to_ETH_Direct() public {
        uint256 orderId = 12349;
        uint256 rawdata = REVERSE_MASK | _MODE_DIRECT | SWAP_AMOUNT;
        
        vm.startPrank(alice);
        
        // Approve WETH directly to DexRouter
        IERC20(WETH).approve(address(dexRouter), type(uint256).max);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        dexRouter.swapWrap(orderId, rawdata);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        uint256 ethAfter = alice.balance;
        
        assertEq(wethBefore - wethAfter, SWAP_AMOUNT, "WETH balance should decrease by SWAP_AMOUNT");
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with PERMIT2_SIGNATURE mode + fromToken Commission + toToken Trim
    function test_swapWrap_WETH_to_ETH_Permit2Signature_WithCommissionAndTrim() public {
        uint256 DENOMINATOR = 10 ** 9;
        uint256 totalRate = 2 * 1_000_000;
        uint256 totalAmount = SWAP_AMOUNT; // Alice inputs exactly 1 WETH
        uint256 inputAmount = totalAmount * (DENOMINATOR - totalRate) / DENOMINATOR;
        
        bytes memory callData;
        {
            uint256 orderId = 12350;
            uint256 rawdata = REVERSE_MASK | _MODE_PERMIT2_SIGNATURE | inputAmount;
            
            // For ToB mode, all tokens (swap + commission) go to router, so permitLength = 1
            uint256[] memory maxAmounts = new uint256[](1);
            maxAmounts[0] = totalAmount;  // Total amount including commission
            
            ISignatureTransfer.PermitBatchTransferFrom memory permit = getPermitBatchTransferFrom(
                WETH, 
                maxAmounts, 
                0, 
                uint48(block.timestamp + 1000)
            );
            
            bytes memory signature = getPermitBatchTransferSignature(
                permit,
                alicePrivateKey,
                address(dexRouter),
                Permit2EthDomainSeperator
            );

            address commissionAddress1 = vm.addr(200001);
            address commissionAddress2 = vm.addr(200002);
            address trimAddress1 = vm.addr(200003);
            address trimAddress2 = vm.addr(200004);

            // Build trim data dynamically
            bytes memory trimData = abi.encodePacked(
                bytes6(0x777777772222),    // flag
                bytes2(0x0000),            // padding
                bytes4(0x0000000a),        // trimRate = 10
                trimAddress1,              // 20 bytes
                bytes6(0x777777772222),    // flag
                bytes26(0),                // padding + toBTrim
                bytes6(0x777777772222),    // flag
                bytes2(0x0000),            // padding
                bytes4(0x0000000a),        // chargeRate = 10
                trimAddress2               // 20 bytes
            );
            
            // Build commission data dynamically
            bytes memory commissionData = abi.encodePacked(
                bytes6(0x22220afc2aaa),   // flag = FROM_TOKEN_COMMISSION_DUAL
                bytes6(0x0000000f4240),   // rate = 1,000,000 (1% of 10,000,000)
                commissionAddress1,        // 20 bytes
                bytes6(0x800000000000),   // toBCommission flag (toB mode)
                bytes6(0),                // padding (6 bytes)
                address(WETH),            // WETH token (fromToken)
                bytes6(0x22220afc2aaa),   // flag = FROM_TOKEN_COMMISSION_DUAL
                bytes6(0x0000000f4240),   // rate = 1,000,000 (1%)
                commissionAddress2         // 20 bytes
            );
            
            callData = abi.encodeWithSelector(dexRouter.swapWrap.selector, orderId, rawdata);
            callData = bytes.concat(
                callData,
                _buildPermit2InfoUnified(maxAmounts, 0, uint48(block.timestamp + 1000), alice, signature),
                trimData,
                commissionData
            );
        }
        
        vm.startPrank(alice);
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        
        (bool success, bytes memory returnData) = address(dexRouter).call(callData);
        assertFalse(success, "swapWrap should revert when trim is used");
        
        // Decode revert reason and verify it matches expected message
        assertGt(returnData.length, 4, "Should have revert reason");
        bytes memory expectedError = abi.encodeWithSignature("Error(string)", "trim is not supported in swapWrap");
        assertEq(keccak256(returnData), keccak256(expectedError), "Revert reason should be 'trim is not supported in swapWrap'");
        
        vm.stopPrank();
    }

    /// @notice Test ETH -> WETH with fromToken Commission (Legacy mode)
    function test_swapWrap_ETH_to_WETH_WithFromTokenCommission() public {
        uint256 DENOMINATOR = 10 ** 9;
        uint256 totalRate = 2_000_000; // 0.2%
        uint256 swapAmount = SWAP_AMOUNT;
        uint256 commissionAmount = swapAmount * totalRate / (DENOMINATOR - totalRate);
        
        address commissionAddress1 = vm.addr(300001);
        address commissionAddress2 = vm.addr(300002);
        
        bytes memory callData;
        {
            bytes memory commissionData = abi.encodePacked(
                bytes6(0x22220afc2aaa),
                bytes6(uint48(1_000_000)),
                commissionAddress1,
                bytes6(0x800000000000),
                bytes6(0),
                ETH,
                bytes6(0x22220afc2aaa),
                bytes6(uint48(1_000_000)),
                commissionAddress2
            );
            
            callData = abi.encodeWithSelector(dexRouter.swapWrap.selector, 12360, swapAmount);
            callData = bytes.concat(callData, commissionData);
        }
        
        vm.startPrank(alice);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        (bool success, ) = address(dexRouter).call{value: swapAmount + commissionAmount}(callData);
        require(success, "swapWrap call failed");
        
        uint256 wethReceived = IERC20(WETH).balanceOf(alice) - wethBefore;
        uint256 ethSpent = ethBefore - alice.balance;
        uint256 commission1Received = commissionAddress1.balance;
        uint256 commission2Received = commissionAddress2.balance;
        
        console.log("Alice WETH received:", wethReceived);
        console.log("Alice ETH spent:", ethSpent);
        console.log("Commission1 ETH:", commission1Received);
        console.log("Commission2 ETH:", commission2Received);
        
        assertEq(wethReceived, swapAmount, "WETH should increase by swap amount");
        assertEq(ethSpent, swapAmount + commissionAmount, "ETH spent should equal amount + commission");
        assertGt(commission1Received, 0, "Commission1 should receive ETH");
        assertGt(commission2Received, 0, "Commission2 should receive ETH");
        assertEq(commission1Received + commission2Received, commissionAmount, "Total commission should match");
        
        vm.stopPrank();
    }

    /// @notice Test ETH -> WETH with fromToken Commission via swapWrapToWithBaseRequest
    function test_swapWrapToWithBaseRequest_ETH_to_WETH_WithFromTokenCommission() public {
        uint256 DENOMINATOR = 10 ** 9;
        uint256 totalRate = 2_000_000; // 0.2%
        uint256 swapAmount = SWAP_AMOUNT;
        uint256 commissionAmount = swapAmount * totalRate / (DENOMINATOR - totalRate);
        
        address commissionAddress1 = vm.addr(400001);
        address commissionAddress2 = vm.addr(400002);
        
        bytes memory callData;
        {
            bytes memory commissionData = abi.encodePacked(
                bytes6(0x22220afc2aaa),
                bytes6(uint48(1_000_000)),
                commissionAddress1,
                bytes6(0x800000000000),
                bytes6(0),
                ETH,
                bytes6(0x22220afc2aaa),
                bytes6(uint48(1_000_000)),
                commissionAddress2
            );
            
            IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
                fromToken: uint256(uint160(ETH)), // mode = 0 (LEGACY)
                toToken: WETH,
                fromTokenAmount: swapAmount,
                minReturnAmount: swapAmount,
                deadLine: block.timestamp + 1000
            });
            
            callData = abi.encodeWithSelector(
                dexRouter.swapWrapToWithBaseRequest.selector, 
                22360, 
                bob, 
                baseRequest
            );
            callData = bytes.concat(callData, commissionData);
        }
        
        vm.startPrank(alice);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(bob);
        uint256 aliceEthBefore = alice.balance;
        
        (bool success, ) = address(dexRouter).call{value: swapAmount + commissionAmount}(callData);
        require(success, "swapWrapToWithBaseRequest call failed");
        
        uint256 wethReceived = IERC20(WETH).balanceOf(bob) - wethBefore;
        uint256 aliceEthSpent = aliceEthBefore - alice.balance;
        uint256 commission1Received = commissionAddress1.balance;
        uint256 commission2Received = commissionAddress2.balance;
        
        console.log("Alice ETH spent:", aliceEthSpent);
        console.log("Bob WETH received:", wethReceived);
        console.log("Commission1 ETH:", commission1Received);
        console.log("Commission2 ETH:", commission2Received);
        
        assertEq(wethReceived, swapAmount, "Receiver WETH should increase by swap amount");
        assertGt(commission1Received, 0, "Commission1 should receive ETH");
        assertGt(commission2Received, 0, "Commission2 should receive ETH");
        
        vm.stopPrank();
    }

    // ============================================
    // Test swapWrapToWithBaseRequest function
    // ============================================

    /// @notice Test ETH -> WETH with LEGACY mode
    function test_swapWrapToWithBaseRequest_ETH_to_WETH_Legacy() public {
        uint256 orderId = 22345;
        address receiver = bob;
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(ETH)), // mode = 0 (LEGACY)
            toToken: WETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        vm.startPrank(alice);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(bob);
        
        dexRouter.swapWrapToWithBaseRequest{value: SWAP_AMOUNT}(orderId, receiver, baseRequest);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(bob);
        
        assertEq(wethAfter - wethBefore, SWAP_AMOUNT, "Receiver WETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with LEGACY mode
    function test_swapWrapToWithBaseRequest_WETH_to_ETH_Legacy() public {
        uint256 orderId = 22346;
        address receiver = bob;
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(WETH)), // mode = 0 (LEGACY)
            toToken: ETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        vm.startPrank(alice);
        
        // Approve WETH to ApproveProxy
        IERC20(WETH).approve(address(tokenApprove), type(uint256).max);
        
        uint256 ethBefore = bob.balance;
        
        dexRouter.swapWrapToWithBaseRequest(orderId, receiver, baseRequest);
        
        uint256 ethAfter = bob.balance;
        
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "Receiver ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with PERMIT2_ALLOWANCE mode
    function test_swapWrapToWithBaseRequest_WETH_to_ETH_Permit2Allowance() public {
        uint256 orderId = 22347;
        address receiver = bob;
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: _MODE_PERMIT2_ALLOWANCE | uint256(uint160(WETH)),
            toToken: ETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        vm.startPrank(alice);
        
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        IPermit2Approve(address(permit2)).approve(WETH, address(dexRouter), type(uint160).max, type(uint48).max);
        
        uint256 ethBefore = bob.balance;
        
        dexRouter.swapWrapToWithBaseRequest(orderId, receiver, baseRequest);
        
        uint256 ethAfter = bob.balance;
        
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "Receiver ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with PERMIT2_SIGNATURE mode
    function test_swapWrapToWithBaseRequest_WETH_to_ETH_Permit2Signature() public {
        uint256 orderId = 22348;
        address receiver = bob;
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: _MODE_PERMIT2_SIGNATURE | uint256(uint160(WETH)),
            toToken: ETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        // Generate Permit2 signature
        uint256 nonce = 0;
        uint48 deadline = uint48(block.timestamp + 1000);
        
        // Use batch transfer with single amount
        uint256[] memory maxAmounts = new uint256[](1);
        maxAmounts[0] = SWAP_AMOUNT;
        
        ISignatureTransfer.PermitBatchTransferFrom memory permit = getPermitBatchTransferFrom(
            WETH,
            maxAmounts,
            nonce,
            deadline
        );
        
        bytes memory signature = getPermitBatchTransferSignature(
            permit,
            alicePrivateKey,
            address(dexRouter),
            Permit2EthDomainSeperator
        );
        
        // Encode Permit2Info in calldata
        bytes memory permit2Data = _buildPermit2InfoUnified(maxAmounts, nonce, deadline, alice, signature);
        
        vm.startPrank(alice);
        
        // Approve WETH to Permit2
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        
        uint256 ethBefore = bob.balance;
        
        // Call with permit2Data appended
        (bool success, ) = address(dexRouter).call(
            abi.encodePacked(
                abi.encodeWithSelector(dexRouter.swapWrapToWithBaseRequest.selector, orderId, receiver, baseRequest),
                permit2Data
            )
        );
        require(success, "swapWrapToWithBaseRequest call failed");
        
        uint256 ethAfter = bob.balance;
        
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "Receiver ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    /// @notice Test WETH -> ETH with DIRECT mode
    function test_swapWrapToWithBaseRequest_WETH_to_ETH_Direct() public {
        uint256 orderId = 22349;
        address receiver = bob;
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: _MODE_DIRECT | uint256(uint160(WETH)),
            toToken: ETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        vm.startPrank(alice);
        
        // Approve WETH directly to DexRouter
        IERC20(WETH).approve(address(dexRouter), type(uint256).max);
        
        uint256 ethBefore = bob.balance;
        
        dexRouter.swapWrapToWithBaseRequest(orderId, receiver, baseRequest);
        
        uint256 ethAfter = bob.balance;
        
        assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "Receiver ETH balance should increase by SWAP_AMOUNT");
        
        vm.stopPrank();
    }

    // ============================================
    // Test Refund Logic
    // ============================================

    /// @notice Test 1: ETH -> WETH with overpayment, should refund excess ETH
    function test_swapWrap_Refund_ExcessETH() public {
        // Clean up router balances from previous tests
        if (address(dexRouter).balance > 0) {
            vm.deal(address(dexRouter), 0);
        }
        
        uint256 orderId = 30001;
        uint256 rawdata = SWAP_AMOUNT; // mode = 0 (LEGACY), reversed = false
        uint256 excessAmount = 0.1 ether; // User sends extra 0.1 ETH
        uint256 totalSent = SWAP_AMOUNT + excessAmount;
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        uint256 routerEthBefore = address(dexRouter).balance;
        
        // Send more ETH than needed
        // Refund will be sent to msg.sender (alice) via swapCache.refundTo
        vm.prank(alice);
        dexRouter.swapWrap{value: totalSent}(orderId, rawdata);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(alice);
        uint256 ethAfter = alice.balance;
        uint256 routerEthAfter = address(dexRouter).balance;
        
        console.log("ETH sent:", totalSent);
        console.log("WETH received:", wethAfter - wethBefore);
        console.log("ETH spent:", ethBefore - ethAfter);
        console.log("ETH refunded:", totalSent - (ethBefore - ethAfter));
        console.log("Router ETH balance:", routerEthAfter);
        
        // Assertions
        assertEq(wethAfter - wethBefore, SWAP_AMOUNT, "WETH should increase by exact SWAP_AMOUNT");
        assertEq(ethBefore - ethAfter, SWAP_AMOUNT, "ETH spent should be exact SWAP_AMOUNT (excess refunded)");
        assertEq(routerEthAfter, routerEthBefore, "Router should not keep any ETH");
    }

    // /// @notice Test 3: WETH -> ETH with excess WETH in router, should refund to user
    // /// @dev Simulates scenario where router has leftover WETH and verifies it gets refunded
    // function test_swapWrap_Refund_ExcessWETH() public {
    //     // Clean up router balances from previous tests
    //     if (address(dexRouter).balance > 0) {
    //         vm.deal(address(dexRouter), 0);
    //     }
    //     uint256 routerWethBalance = IERC20(WETH).balanceOf(address(dexRouter));
    //     if (routerWethBalance > 0) {
    //         vm.prank(address(dexRouter));
    //         IERC20(WETH).transfer(address(0xdead), routerWethBalance);
    //     }
        
    //     uint256 orderId = 30003;
    //     uint256 rawdata = REVERSE_MASK | SWAP_AMOUNT; // mode = 0 (LEGACY), reversed = true
    //     uint256 excessAmount = 0.08 ether; // Simulate leftover WETH
        
    //     vm.startPrank(alice);
        
    //     // Approve WETH to ApproveProxy
    //     IERC20(WETH).approve(address(tokenApprove), type(uint256).max);
        
    //     uint256 wethBefore = IERC20(WETH).balanceOf(alice);
    //     uint256 ethBefore = alice.balance;
        
    //     // Simulate leftover WETH in router (e.g., from rounding in previous operations)
    //     // This represents WETH that belongs to no one and should be refunded to current user
    //     IERC20(WETH).transfer(address(dexRouter), excessAmount);
        
    //     dexRouter.swapWrap(orderId, rawdata);
        
    //     uint256 wethAfter = IERC20(WETH).balanceOf(alice);
    //     uint256 ethAfter = alice.balance;
    //     uint256 routerWethAfter = IERC20(WETH).balanceOf(address(dexRouter));
        
    //     console.log("WETH spent (including excess):", wethBefore - wethAfter);
    //     console.log("ETH received:", ethAfter - ethBefore);
    //     console.log("WETH refunded:", wethAfter - (wethBefore - SWAP_AMOUNT - excessAmount));
    //     console.log("Router WETH after:", routerWethAfter);
        
    //     // Assertions
    //     // Net WETH change: Alice sent excessAmount manually, then SWAP_AMOUNT via swap, got excessAmount back
    //     assertEq(wethBefore - wethAfter, SWAP_AMOUNT, "Net WETH spent should be SWAP_AMOUNT (excess refunded)");
    //     assertEq(ethAfter - ethBefore, SWAP_AMOUNT, "ETH received should be SWAP_AMOUNT");
    //     assertEq(routerWethAfter, 0, "Router should not keep any WETH (all excess refunded)");
        
    //     vm.stopPrank();
    // }

    /// @notice Test: swapWrapToWithBaseRequest with ETH overpayment, should refund excess ETH
    /// @dev Verifies refund logic works correctly through swapWrapToWithBaseRequest entry point
    function test_swapWrapToWithBaseRequest_Refund_ExcessETH() public {
        // Clean up router balances from previous tests
        if (address(dexRouter).balance > 0) {
            vm.deal(address(dexRouter), 0);
        }
        
        uint256 orderId = 40001;
        uint256 excessAmount = 0.15 ether; // User sends extra 0.15 ETH
        uint256 totalSent = SWAP_AMOUNT + excessAmount;
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(ETH)), // mode = 0 (LEGACY)
            toToken: WETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        uint256 wethBefore = IERC20(WETH).balanceOf(bob);
        uint256 aliceEthBefore = alice.balance;
        
        // Send more ETH than needed, receiver is bob
        // Refund will be sent to msg.sender (alice) via swapCache.refundTo
        vm.prank(alice);
        dexRouter.swapWrapToWithBaseRequest{value: totalSent}(orderId, bob, baseRequest);
        
        uint256 wethAfter = IERC20(WETH).balanceOf(bob);
        uint256 aliceEthAfter = alice.balance;
        
        console.log("ETH sent:", totalSent);
        console.log("Bob WETH received:", wethAfter - wethBefore);
        console.log("Alice ETH spent:", aliceEthBefore - aliceEthAfter);
        console.log("Alice ETH refunded:", totalSent - (aliceEthBefore - aliceEthAfter));
        
        // Assertions
        assertEq(wethAfter - wethBefore, SWAP_AMOUNT, "Bob should receive exact SWAP_AMOUNT WETH");
        assertEq(aliceEthBefore - aliceEthAfter, SWAP_AMOUNT, "Alice should only spend SWAP_AMOUNT ETH (excess refunded)");
        assertEq(address(dexRouter).balance, 0, "Router should not keep any ETH");
    }
}

