// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PMMAdapter, IPMMProtocol} from "@dex/adapter/PmmAdapter.sol";
import "forge-std/Test.sol";
import {IWETH} from "@dex/interfaces/IWETH.sol";
import {IPermit2} from "@dex/interfaces/IPermit2.sol";
import {TestHelper} from "./helpers/RFQTestHelper.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {OrderRFQLib} from "./helpers/RFQTestHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console2} from "forge-std/console2.sol";
// Remove the duplicate interface since we're importing PMMAdapter which has it

contract PmmProtocolPermitWitnessFork is TestHelper {
    IPMMProtocol public pool;
    PMMAdapter public adapter;
    address constant ARBITRUM_WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant usdt = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address constant usdc = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address constant PMM_PROTOCOL = 0x5C1c902e7E04DE98b49aCd3De68E12BEE2d7908D;
    address constant PAYER_ORIGIN = address(0x5678);
    
    uint256 constant ORIGIN_PAYER = 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    // Example Witness Struct
    struct ExampleWitness {
        address user;
    }

    bytes32 constant EXAMPLE_WITNESS_TYPEHASH = keccak256("ExampleWitness(address user)");
    string constant WITNESS_TYPE_STRING = "ExampleWitness witness)ExampleWitness(address user)";

    function setUp() public {
        vm.createSelectFork("arb");
        pool = IPMMProtocol(PMM_PROTOCOL);
        adapter = new PMMAdapter();

        // Use deal with adjust=true for proxy token support
        deal(usdc, MAKER_ADDRESS, 100_000, true);
        deal(usdt, MAKER_ADDRESS, 100_000, true); // Maker needs USDT for sellQuote test
        deal(usdt, TAKER_ADDRESS, 200_000, true); // Extra for surplus test
        deal(usdc, TAKER_ADDRESS, 200_000, true); // Extra for surplus test

        // Maker approves both tokens to Permit2
        vm.startPrank(MAKER_ADDRESS);
        SafeERC20.forceApprove(IERC20(usdc), permit2, type(uint256).max);
        SafeERC20.forceApprove(IERC20(usdt), permit2, type(uint256).max);
        vm.stopPrank();

        vm.prank(TAKER_ADDRESS);
        SafeERC20.forceApprove(IERC20(usdt), address(pool), type(uint256).max);
    }


    function testAdapterSellBaseWithPermitWitnessTransfer() public {
        // Create Witness Data
        ExampleWitness memory witnessData = ExampleWitness({user: MAKER_ADDRESS});
        bytes32 witness = keccak256(abi.encode(EXAMPLE_WITNESS_TYPEHASH, witnessData));

        // Create Order
        OrderRFQLib.OrderRFQ memory order =
            createOrder(13580, block.timestamp + 1000, usdc, usdt, MAKER_ADDRESS, 100000, 90000, true);

        // Set Witness Fields
        order.permit2Witness = witness;
        order.permit2WitnessType = WITNESS_TYPE_STRING;

        // Sign for Permit2 Witness
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({token: usdc, amount: order.makerAmount}),
            nonce: order.rfqId,
            deadline: order.expiry
        });

        bytes memory permit2Signature = getPermit2WitnessSignature(
            permit, address(pool), witness, WITNESS_TYPE_STRING, MAKER_PRIVATE_KEY, IPermit2(permit2).DOMAIN_SEPARATOR()
        );
        order.permit2Signature = permit2Signature;

        // Sign Order
        bytes memory orderSignature = signOrder(order, pool.DOMAIN_SEPARATOR(), MAKER_PRIVATE_KEY);

        // Create adapter moreInfo
        bytes memory moreInfo = abi.encode(order, orderSignature, uint256(0)); // EIP712 = 0

        // Encode payer origin in calldata
        uint256 payerOriginEncoded = ORIGIN_PAYER | uint256(uint160(PAYER_ORIGIN));

        uint256 adapterBalanceBefore = IERC20(usdt).balanceOf(address(adapter));
        uint256 takerBalanceBefore = IERC20(usdc).balanceOf(TAKER_ADDRESS);
        uint256 takerUsdtBefore = IERC20(usdt).balanceOf(TAKER_ADDRESS);
        uint256 makerBalanceBefore = IERC20(usdt).balanceOf(MAKER_ADDRESS);

        // Step 1: Taker transfers USDT (takerAsset) to adapter
        // This simulates the real flow where user sends tokens to adapter first
        console2.log("[Taker] USDT: ", IERC20(usdt).balanceOf(TAKER_ADDRESS));
        console2.log("[Taker] USDC: ", IERC20(usdc).balanceOf(TAKER_ADDRESS));
        console2.log("[Maker] USDT: ", IERC20(usdt).balanceOf(MAKER_ADDRESS));
        console2.log("[Maker] USDC: ", IERC20(usdc).balanceOf(MAKER_ADDRESS));
        
        vm.prank(TAKER_ADDRESS);
        IERC20(usdt).transfer(address(adapter), order.takerAmount);
        // Step 2: Execute via adapter (can be called by anyone, not necessarily taker)
        adapter.sellBase(TAKER_ADDRESS, address(pool), moreInfo);
        console2.log("Afte Swap");
        console2.log("[Taker] USDT: ", IERC20(usdt).balanceOf(TAKER_ADDRESS));
        console2.log("[Taker] USDC: ", IERC20(usdc).balanceOf(TAKER_ADDRESS));
        console2.log("[Maker] USDT: ", IERC20(usdt).balanceOf(MAKER_ADDRESS));
        console2.log("[Maker] USDC: ", IERC20(usdc).balanceOf(MAKER_ADDRESS));
        // Verify Balances
        assertEq(IERC20(usdc).balanceOf(TAKER_ADDRESS), takerBalanceBefore + order.makerAmount, "Taker should receive USDC (maker tokens)");
        assertEq(IERC20(usdt).balanceOf(TAKER_ADDRESS), takerUsdtBefore - order.takerAmount, "Taker should have spent USDT (taker tokens)");
        assertEq(IERC20(usdt).balanceOf(MAKER_ADDRESS), makerBalanceBefore + order.takerAmount, "Maker should receive USDT (taker tokens)");
        assertEq(IERC20(usdt).balanceOf(address(adapter)), adapterBalanceBefore, "Adapter USDT balance should return to original");
    }

    function testAdapterErrorHandlingWithPermitWitness() public {
        // Create an expired order to test error handling
        OrderRFQLib.OrderRFQ memory order =
            createOrder(13581, block.timestamp - 1, usdc, usdt, MAKER_ADDRESS, 100000, 90000, true); // Expired

        // Set Witness Fields (even though order is expired)
        ExampleWitness memory witnessData = ExampleWitness({user: MAKER_ADDRESS});
        bytes32 witness = keccak256(abi.encode(EXAMPLE_WITNESS_TYPEHASH, witnessData));
        order.permit2Witness = witness;
        order.permit2WitnessType = WITNESS_TYPE_STRING;

        // Sign Order
        bytes memory orderSignature = signOrder(order, pool.DOMAIN_SEPARATOR(), MAKER_PRIVATE_KEY);

        // Create adapter moreInfo
        bytes memory moreInfo = abi.encode(order, orderSignature, uint256(0)); // EIP712 = 0

        uint256 payerOriginEncoded = ORIGIN_PAYER | uint256(uint160(PAYER_ORIGIN));

        vm.prank(TAKER_ADDRESS);
        vm.expectRevert(abi.encodePacked("RFQ_OrderExpired ", Strings.toString(order.rfqId)));
        (bool success,) = address(adapter).call(
            abi.encodeWithSelector(
                adapter.sellBase.selector,
                TAKER_ADDRESS,
                address(pool),
                moreInfo
            ).concat(abi.encode(payerOriginEncoded))
        );
    }

    function testAdapterSurplusReturnWithPermitWitness() public {
        // Create Witness Data
        ExampleWitness memory witnessData = ExampleWitness({user: MAKER_ADDRESS});
        bytes32 witness = keccak256(abi.encode(EXAMPLE_WITNESS_TYPEHASH, witnessData));

        // Create Order
        OrderRFQLib.OrderRFQ memory order =
            createOrder(13582, block.timestamp + 1000, usdc, usdt, MAKER_ADDRESS, 100000, 90000, true);

        // Set Witness Fields
        order.permit2Witness = witness;
        order.permit2WitnessType = WITNESS_TYPE_STRING;

        // Sign for Permit2 Witness
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({token: usdc, amount: order.makerAmount}),
            nonce: order.rfqId,
            deadline: order.expiry
        });

        bytes memory permit2Signature = getPermit2WitnessSignature(
            permit, address(pool), witness, WITNESS_TYPE_STRING, MAKER_PRIVATE_KEY, IPermit2(permit2).DOMAIN_SEPARATOR()
        );
        order.permit2Signature = permit2Signature;

        // Sign Order
        bytes memory orderSignature = signOrder(order, pool.DOMAIN_SEPARATOR(), MAKER_PRIVATE_KEY);

        // Create adapter moreInfo
        bytes memory moreInfo = abi.encode(order, orderSignature, uint256(0)); // EIP712 = 0

        uint256 payerOriginEncoded = ORIGIN_PAYER | uint256(uint160(PAYER_ORIGIN));
        uint256 payerBalanceBefore = IERC20(usdt).balanceOf(PAYER_ORIGIN);

        console2.log("=== Before Transfer ===");
        console2.log("[Taker] USDT: ", IERC20(usdt).balanceOf(TAKER_ADDRESS));
        console2.log("[Taker] USDC: ", IERC20(usdc).balanceOf(TAKER_ADDRESS));
        console2.log("[Maker] USDT: ", IERC20(usdt).balanceOf(MAKER_ADDRESS));
        console2.log("[Maker] USDC: ", IERC20(usdc).balanceOf(MAKER_ADDRESS));
        console2.log("[Adapter] USDT: ", IERC20(usdt).balanceOf(address(adapter)));
        console2.log("[Payer] USDT: ", IERC20(usdt).balanceOf(PAYER_ORIGIN));

        // Step 1: Transfer required tokens PLUS extra surplus to adapter
        vm.prank(TAKER_ADDRESS);
        IERC20(usdt).transfer(address(adapter), order.takerAmount + 50000); // takerAmount + extra surplus
        // Execute via adapter
        (bool success,) = address(adapter).call(
            abi.encodeWithSelector(
                adapter.sellBase.selector,
                TAKER_ADDRESS,
                address(pool),
                moreInfo
            ).concat(abi.encode(payerOriginEncoded))
        );

        assertTrue(success, "Adapter call should succeed");

        console2.log("\n=== After Swap ===");
        console2.log("[Taker] USDT: ", IERC20(usdt).balanceOf(TAKER_ADDRESS));
        console2.log("[Taker] USDC: ", IERC20(usdc).balanceOf(TAKER_ADDRESS));
        console2.log("[Maker] USDT: ", IERC20(usdt).balanceOf(MAKER_ADDRESS));
        console2.log("[Maker] USDC: ", IERC20(usdc).balanceOf(MAKER_ADDRESS));
        console2.log("[Adapter] USDT: ", IERC20(usdt).balanceOf(address(adapter)));
        console2.log("[Payer] USDT: ", IERC20(usdt).balanceOf(PAYER_ORIGIN));

        // Check that surplus was returned to payer origin
        uint256 payerBalanceAfter = IERC20(usdt).balanceOf(PAYER_ORIGIN);
        assertTrue(payerBalanceAfter > payerBalanceBefore, "Surplus should be returned to payer origin");
    }

    function testAdapterSellQuoteWithPermitWitnessTransfer() public {
        // Create Witness Data
        ExampleWitness memory witnessData = ExampleWitness({user: MAKER_ADDRESS});
        bytes32 witness = keccak256(abi.encode(EXAMPLE_WITNESS_TYPEHASH, witnessData));

        // Create Order - for sellQuote, taker sells USDC (quote) to get USDT (base)
        // So we swap the assets: maker provides USDT, taker provides USDC
        OrderRFQLib.OrderRFQ memory order =
            createOrder(13586, block.timestamp + 1000, usdt, usdc, MAKER_ADDRESS, 90000, 100000, true);

        // Set Witness Fields
        order.permit2Witness = witness;
        order.permit2WitnessType = WITNESS_TYPE_STRING;

        // Sign for Permit2 Witness (maker will provide USDT via Permit2)
        IPermit2.PermitTransferFrom memory permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({token: usdt, amount: order.makerAmount}),
            nonce: order.rfqId,
            deadline: order.expiry
        });

        bytes memory permit2Signature = getPermit2WitnessSignature(
            permit, address(pool), witness, WITNESS_TYPE_STRING, MAKER_PRIVATE_KEY, IPermit2(permit2).DOMAIN_SEPARATOR()
        );
        order.permit2Signature = permit2Signature;

        // Sign Order
        bytes memory orderSignature = signOrder(order, pool.DOMAIN_SEPARATOR(), MAKER_PRIVATE_KEY);

        // Create adapter moreInfo
        bytes memory moreInfo = abi.encode(order, orderSignature, uint256(0)); // EIP712 = 0

        // Encode payer origin in calldata
        uint256 payerOriginEncoded = ORIGIN_PAYER | uint256(uint160(PAYER_ORIGIN));

        uint256 adapterBalanceBefore = IERC20(usdc).balanceOf(address(adapter));
        uint256 takerUsdtBefore = IERC20(usdt).balanceOf(TAKER_ADDRESS);
        uint256 takerUsdcBefore = IERC20(usdc).balanceOf(TAKER_ADDRESS);
        uint256 makerBalanceBefore = IERC20(usdc).balanceOf(MAKER_ADDRESS);

        // Step 1: Taker transfers USDC (takerAsset/quote token) to adapter
        console2.log("[Taker] USDT: ", IERC20(usdt).balanceOf(TAKER_ADDRESS));
        console2.log("[Taker] USDC: ", IERC20(usdc).balanceOf(TAKER_ADDRESS));
        console2.log("[Maker] USDT: ", IERC20(usdt).balanceOf(MAKER_ADDRESS));
        console2.log("[Maker] USDC: ", IERC20(usdc).balanceOf(MAKER_ADDRESS));
        
        vm.prank(TAKER_ADDRESS);
        IERC20(usdc).transfer(address(adapter), order.takerAmount);
        // Step 2: Execute via adapter using sellQuote
        adapter.sellQuote(TAKER_ADDRESS, address(pool), moreInfo);
        console2.log("After Swap");
        console2.log("[Taker] USDT: ", IERC20(usdt).balanceOf(TAKER_ADDRESS));
        console2.log("[Taker] USDC: ", IERC20(usdc).balanceOf(TAKER_ADDRESS));
        console2.log("[Maker] USDT: ", IERC20(usdt).balanceOf(MAKER_ADDRESS));
        console2.log("[Maker] USDC: ", IERC20(usdc).balanceOf(MAKER_ADDRESS));
        // Verify Balances
        assertEq(IERC20(usdt).balanceOf(TAKER_ADDRESS), takerUsdtBefore + order.makerAmount, "Taker should receive USDT (maker tokens)");
        assertEq(IERC20(usdc).balanceOf(TAKER_ADDRESS), takerUsdcBefore - order.takerAmount, "Taker should have spent USDC (taker tokens)");
        assertEq(IERC20(usdc).balanceOf(MAKER_ADDRESS), makerBalanceBefore + order.takerAmount, "Maker should receive USDC (taker tokens)");
        assertEq(IERC20(usdc).balanceOf(address(adapter)), adapterBalanceBefore, "Adapter USDC balance should return to original");
    }

    // Helper to sign Permit2 Witness Typed Data
    function getPermit2WitnessSignature(
        IPermit2.PermitTransferFrom memory permit,
        address spender,
        bytes32 witness,
        string memory witnessTypeString,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory) {
        bytes32 TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

        // The typehash for PermitWitnessTransferFrom includes the witness type definition
        // Construct full type string: "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline," + witnessTypeString
        // Note: The witnessTypeString usually looks like "WitnessType witness)WitnessType(..."

        // We manually reconstruct the type hash logic based on EIP-712 and Permit2 specs
        // Keccak("PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline," + witnessTypeString)

        bytes32 PERMIT_WITNESS_TRANSFER_FROM_TYPEHASH = keccak256(
            abi.encodePacked(
                "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,",
                witnessTypeString
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_WITNESS_TRANSFER_FROM_TYPEHASH,
                keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted)),
                spender,
                permit.nonce,
                permit.deadline,
                witness
            )
        );

        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        return abi.encodePacked(r, s, v);
    }
}

// Helper library to concatenate bytes
library BytesLib {
    function concat(bytes memory a, bytes memory b) internal pure returns (bytes memory) {
        return abi.encodePacked(a, b);
    }
}

// Add the concat function to bytes
using BytesLib for bytes;

