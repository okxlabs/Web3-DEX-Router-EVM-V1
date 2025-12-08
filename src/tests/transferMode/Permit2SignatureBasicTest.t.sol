// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/Permit2Helper.t.sol";
import "@dex/interfaces/IPermit2.sol";
import "@dex/interfaces/IERC20.sol";

// Contract for testing permit2 transfer from
contract Permit2TokenTransfer {
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    struct Permit2Info {
        IPermit2.PermitTransferFrom permit;
        address owner;
        bytes signature;
    }

    function permit2TransferFrom(
        Permit2Info memory permit2Info,
        address to,
        uint256 amount
    ) public {
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: to,
            requestedAmount: amount
        });
        IPermit2(PERMIT2).permitTransferFrom(permit2Info.permit, transferDetails, permit2Info.owner, permit2Info.signature);
    }

    function permit2BatchTransferFrom(
        IPermit2.PermitBatchTransferFrom memory permit,
        IPermit2.SignatureTransferDetails[] memory transferDetails,
        address owner,
        bytes memory signature
    ) public {
        IPermit2(PERMIT2).permitTransferFrom(permit, transferDetails, owner, signature);
    }
}

contract Permit2SignatureBasicTest is Permit2Helper {
    Permit2TokenTransfer public permit2Transfer;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // decimals=18
    address public arnaud = vm.rememberKey(11111111111111111111);
    address public bob = vm.rememberKey(11111111112222222222);
    address public charles = vm.rememberKey(11111111113333333333);
    address public david = vm.rememberKey(11111111114444444444);
    uint256 public arnaudPrivateKey = 11111111111111111111;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23293873); // 2025.9.5 10:18
        permit2Transfer = new Permit2TokenTransfer();
    }

    // ==================== Basic Test for testing permit2TransferFrom ====================
    function test_permit2TransferFrom() public {
        deal(WETH, arnaud, 100 * 10 ** 18);
        console2.log("arnaud:", arnaud);
        console2.log("arnaud WETH balance before:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance before:", IERC20(WETH).balanceOf(bob));

        vm.startPrank(arnaud);
        IERC20(WETH).approve(permit2Transfer.PERMIT2(), type(uint256).max);
        IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
            WETH,
            10 * 10 ** 18,
            0,
            2524579200 // 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            arnaudPrivateKey,
            address(permit2Transfer),
            Permit2EthDomainSeperator
        );
        Permit2TokenTransfer.Permit2Info memory permit2Info = Permit2TokenTransfer.Permit2Info({
            permit: permit,
            owner: arnaud,
            signature: signature
        });
        permit2Transfer.permit2TransferFrom(permit2Info, bob, 1 * 10 ** 18);
        console2.log("arnaud WETH balance after:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance after:", IERC20(WETH).balanceOf(bob));
    }

    function test_permit2BatchTransferFrom() public {
        deal(WETH, arnaud, 100 * 10 ** 18);
        console2.log("arnaud:", arnaud);
        console2.log("arnaud WETH balance before:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance before:", IERC20(WETH).balanceOf(bob));
        console2.log("charles WETH balance before:", IERC20(WETH).balanceOf(charles));
        console2.log("david WETH balance before:", IERC20(WETH).balanceOf(david));

        vm.startPrank(arnaud);
        IERC20(WETH).approve(permit2Transfer.PERMIT2(), type(uint256).max);
        uint256[] memory maxAmounts = new uint256[](3);
        maxAmounts[0] = 10 * 10 ** 18;
        maxAmounts[1] = 20 * 10 ** 18;
        maxAmounts[2] = 30 * 10 ** 18;
        IPermit2.PermitBatchTransferFrom memory permit = getPermitBatchTransferFrom(
            WETH,
            maxAmounts,
            0,
            2524579200 // 2050-01-01 00:00:00
        );
        IPermit2.SignatureTransferDetails[] memory transferDetails = new IPermit2.SignatureTransferDetails[](3);
        transferDetails[0] = IPermit2.SignatureTransferDetails({
            to: bob,
            requestedAmount: 10 * 10 ** 18
        });
        transferDetails[1] = IPermit2.SignatureTransferDetails({
            to: charles,
            requestedAmount: 20 * 10 ** 18
        });
        transferDetails[2] = IPermit2.SignatureTransferDetails({
            to: david,
            requestedAmount: 30 * 10 ** 18
        });
        bytes memory signature = getPermitBatchTransferSignature(
            permit,
            arnaudPrivateKey,
            address(permit2Transfer),
            Permit2EthDomainSeperator
        );
        permit2Transfer.permit2BatchTransferFrom(permit, transferDetails, arnaud, signature);
        console2.log("arnaud WETH balance after:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance after:", IERC20(WETH).balanceOf(bob));
        console2.log("charles WETH balance after:", IERC20(WETH).balanceOf(charles));
        console2.log("david WETH balance after:", IERC20(WETH).balanceOf(david));
    }
}