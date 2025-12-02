// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "../common/Permit2Helper.t.sol";
import "@dex/interfaces/IPermit2.sol";
import "@dex/interfaces/IDexRouter.sol";
import "forge-std/console.sol";

/**
 * @title SwapWrapTest
 * @notice Test swapWrap and swapWrapToWithBaseRequest with different transfer modes
 * @dev Tests ETH <-> WETH swaps with LEGACY, DIRECT, PERMIT2_ALLOWANCE, and PERMIT2_SIGNATURE modes
 */
contract SwapWrapTest is TrimAndCommissionTestBase, Permit2Helper {
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
        
        dexRouter = new DexRouter();
    
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
        
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: WETH,
                amount: SWAP_AMOUNT
            }),
            nonce: nonce,
            deadline: deadline
        });
        
        bytes memory signature = getPermitTransferSignature(
            permit,
            alicePrivateKey,
            address(dexRouter),
            Permit2EthDomainSeperator
        );
        
        bytes memory permit2Data = encodePermit2Info(permit, alice, signature);
        
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
            
            IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({
                    token: WETH,
                    amount: totalAmount
                }),
                nonce: 0,
                deadline: uint48(block.timestamp + 1000)
            });
            
            bytes memory signature = getPermitTransferSignature(
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
                encodePermit2Info(permit, alice, signature),
                trimData,
                commissionData
            );
        }
        
        vm.startPrank(alice);
        IERC20(WETH).approve(address(permit2), type(uint256).max);
        
        uint256 wethBefore = IERC20(WETH).balanceOf(alice);
        uint256 ethBefore = alice.balance;
        
        (bool success, ) = address(dexRouter).call(callData);
        require(success, "swapWrap call failed");
        
        {
            address commissionAddr1 = vm.addr(200001);
            address commissionAddr2 = vm.addr(200002);
            address trimAddr1 = vm.addr(200003);
            address trimAddr2 = vm.addr(200004);
            
            uint256 aliceWethChange = wethBefore - IERC20(WETH).balanceOf(alice);
            uint256 aliceEthChange = alice.balance - ethBefore;
            
            console.log("Alice WETH change:", aliceWethChange);
            console.log("Alice ETH change:", aliceEthChange);
            console.log("Commission1 WETH:", IERC20(WETH).balanceOf(commissionAddr1));
            console.log("Commission2 WETH:", IERC20(WETH).balanceOf(commissionAddr2));
            console.log("Trim1 ETH:", trimAddr1.balance);
            console.log("Trim2 ETH:", trimAddr2.balance);
            
            assertEq(aliceWethChange, totalAmount, "WETH should decrease by total");
            assertGt(aliceEthChange, 0, "Alice should receive ETH");
            assertGt(IERC20(WETH).balanceOf(commissionAddr1), 0, "Commission1 should receive WETH");
            assertGt(IERC20(WETH).balanceOf(commissionAddr2), 0, "Commission2 should receive WETH");
            assertGt(trimAddr1.balance, 0, "Trim1 should receive ETH");
            assertGt(trimAddr2.balance, 0, "Trim2 should receive ETH");
        }
        
        vm.stopPrank();
    }

    // ============================================
    // Test swapWrapToWithBaseRequest function
    // ============================================

    /// @notice Test ETH -> WETH with LEGACY mode
    function test_swapWrapToWithBaseRequest_ETH_to_WETH_Legacy() public {
        uint256 orderId = 22345;
        uint256 receiver = uint256(uint160(bob)); // mode = 0 (LEGACY)
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(ETH)),
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
        uint256 receiver = uint256(uint160(bob)); // mode = 0 (LEGACY)
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(WETH)),
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
        uint256 receiver = _MODE_PERMIT2_ALLOWANCE | uint256(uint160(bob));
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(WETH)),
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
        uint256 receiver = _MODE_PERMIT2_SIGNATURE | uint256(uint160(bob));
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(WETH)),
            toToken: ETH,
            fromTokenAmount: SWAP_AMOUNT,
            minReturnAmount: SWAP_AMOUNT,
            deadLine: block.timestamp + 1000
        });
        
        // Generate Permit2 signature
        uint256 nonce = 0;
        uint48 deadline = uint48(block.timestamp + 1000);
        
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: WETH,
                amount: SWAP_AMOUNT
            }),
            nonce: nonce,
            deadline: deadline
        });
        
        bytes memory signature = getPermitTransferSignature(
            permit,
            alicePrivateKey,
            address(dexRouter),
            Permit2EthDomainSeperator
        );
        
        // Encode Permit2Info in calldata
        bytes memory permit2Data = encodePermit2Info(permit, alice, signature);
        
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
        uint256 receiver = _MODE_DIRECT | uint256(uint160(bob));
        
        IDexRouter.BaseRequest memory baseRequest = IDexRouter.BaseRequest({
            fromToken: uint256(uint160(WETH)),
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
    // Helper functions
    // ============================================

    /// @notice Encode Permit2Info according to DexRouter's expected format
    function encodePermit2Info(
        IPermit2.PermitTransferFrom memory permit,
        address owner,
        bytes memory signature
    ) internal pure returns (bytes memory) {
        // Match the format expected by _getCommissionAndTrimInfo()
        // Reading order (from calldata end):
        // bytes32_5: signature_s
        // bytes32_4: signature_r  
        // bytes32_3: amount
        // bytes32_2: flag(6) + padding(13) + v(1) + deadline(6) + nonce(6)
        // bytes32_1: flag(6) + padding(5) + length(1) + owner(20)
        
        bytes32 signatureR;
        bytes32 signatureS;
        uint8 signatureV;
        
        assembly {
            signatureR := mload(add(signature, 0x20))
            signatureS := mload(add(signature, 0x40))
            signatureV := byte(0, mload(add(signature, 0x60)))
        }
        
        // Construct bytes32_1: flag(6) + padding(5) + length(1) + owner(20)
        bytes32 slot1 = bytes32(
            (uint256(0x92527fff1a65) << 208) |  // flag at high bits
            (uint256(1) << 160) |                // amount_length = 1
            uint256(uint160(owner))              // owner at low bits
        );
        
        // Construct bytes32_2: flag(6) + padding(13) + v(1) + deadline(6) + nonce(6)
        bytes32 slot2 = bytes32(
            (uint256(0x92527fff1a65) << 208) |  // flag at high bits
            (uint256(signatureV) << 96) |        // v at bit 96
            (uint256(permit.deadline) << 48) |   // deadline at bit 48
            uint256(permit.nonce)                // nonce at low bits
        );
        
        bytes32 slot3 = bytes32(permit.permitted.amount);  // amount
        bytes32 slot4 = signatureR;                        // signature_r
        bytes32 slot5 = signatureS;                        // signature_s
        
        return abi.encodePacked(slot5, slot4, slot3, slot2, slot1);
    }
}

