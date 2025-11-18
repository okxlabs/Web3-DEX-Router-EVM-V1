// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "../common/Permit2Helper.t.sol";
import "@dex/interfaces/IPermit2.sol";

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

    function permit2TransferFromAssembly(
        Permit2Info memory permit2Info,
        address to,
        uint256 amount
    ) public {
        uint256 sigLength = permit2Info.signature.length;
        require(sigLength == 64 || sigLength == 65, "signature length must be 64 or 65");
        assembly ("memory-safe") {
            let permit := mload(permit2Info) // permit2Info.permit
            let permitted := mload(permit) // permit2Info.permit.permitted
            let sigPtr := mload(add(permit2Info, 0x40)) // permit2Info.signature

            let freePtr := mload(0x40) // prepair free memory pointer
            // construct calldata
            mstore(freePtr, 0x30f28b7a00000000000000000000000000000000000000000000000000000000)
            mstore(
                add(freePtr, 0x04),
                mload(permitted)
            ) // token
            mstore(
                add(freePtr, 0x24),
                mload(add(permitted, 0x20))
            ) // amount
            mstore(
                add(freePtr, 0x44),
                mload(add(permit, 0x20))
            ) // nonce
            mstore(
                add(freePtr, 0x64),
                mload(add(permit, 0x40))
            ) // deadline
            mstore(
                add(freePtr, 0x84),
                to
            ) // to
            mstore(
                add(freePtr, 0xa4),
                amount
            ) // requestedAmount
            mstore(
                add(freePtr, 0xc4),
                mload(add(permit2Info, 0x20))
            ) // owner
            mstore(
                add(freePtr, 0xe4),
                0x100
            ) // signature offset
            mstore(
                add(freePtr, 0x104),
                sigLength
            ) // signature length
            mstore(
                add(freePtr, 0x124),
                mload(add(sigPtr, 0x20))
            ) // signature r
            mstore(
                add(freePtr, 0x144),
                mload(add(sigPtr, 0x40))
            ) // signature s
            let calldataSize
            switch eq(sigLength, 65)
            case 1 { // signature length == 65
                mstore(
                    add(freePtr, 0x164),
                    shl(248, shr(248, mload(add(sigPtr, 0x60))))
                ) // signature v
                calldataSize := 0x184
                mstore(0x40, add(freePtr, calldataSize)) // update free memory pointer, calldata size == 0x165
            }
            default { // signature length == 64
                calldataSize := 0x164
                mstore(0x40, add(freePtr, calldataSize)) // update free memory pointer, calldata size == 0x164
            }
            
            // execute external call
            let success := call(
                gas(),           // all remaining gas
                PERMIT2,         // Permit2 contract address
                0,               // no ETH sent
                freePtr,         // calldata start position
                calldataSize,    // calldata size
                0,               // no return data
                0                // return data size is 0
            )

            // check if call is successful
            if iszero(success) {
                // if call failed, copy error information and revert
                let returnDataLen := returndatasize()
                returndatacopy(0, 0, returnDataLen)
                revert(0, returnDataLen)
            }
        }
    }
}

contract FromTokenCommissionTest is TrimAndCommissionTestBase, Permit2Helper {
    Permit2TokenTransfer public permit2Transfer;
    uint256 public arnaudPrivateKey = 11111111111111111111;

    function setUp() override public {
        permit2Transfer = new Permit2TokenTransfer();
        super.setUp();
    }

    // ==================== Basic Test for testing getInfo and permit2TransferFrom ====================
    function test_permit2TransferFrom() public {
        deal(WETH, arnaud, 100 * 10 ** 18);
        console2.log("arnaud:", arnaud);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));

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
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));
    }


    function test_permit2TransferFromAssembly() public {
        deal(WETH, arnaud, 100 * 10 ** 18);
        console2.log("arnaud:", arnaud);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));

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
        permit2Transfer.permit2TransferFromAssembly(permit2Info, bob, 2 * 10 ** 18);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));
    }

    // ==================== Test fromToken commission with multi transfer modes ===================
    // (1) WETH->USDT, 3fromCommission, no-toBCommission, legacy mode
    function test_fromTokenCommission_WETH2USDT_3fromCommission_legacy() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (2) WETH->USDT, 3fromCommission, toBCommission, legacy mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_legacy() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (3) WETH->USDT, 3fromCommission, no-toBCommission, direct mode
    function test_fromTokenCommission_WETH2USDT_3fromCommission_direct() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_DIRECT)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_DIRECT);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (4) WETH->USDT, 3fromCommission, toBCommission, direct mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_direct() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_DIRECT)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_DIRECT);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (5) WETH->USDT, 3fromCommission, no-toBCommission, permit2 allowance mode
    function test_fromTokenCommission_WETH2USDT_3fromCommission_permit2Allowance() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_ALLOWANCE)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_ALLOWANCE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (6) WETH->USDT, 3fromCommission, toBCommission, permit2 allowance mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_permit2Allowance() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_ALLOWANCE)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_ALLOWANCE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (7) WETH->USDT, 3fromCommission, no-toBCommission, permit2 signature mode
    function test_fromTokenCommission_WETH2USDT_3fromCommission_permit2Signature() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory permit2Info = _generatePermit2Info(WETH, 2 * 10 ** 18);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (8) WETH->USDT, 3fromCommission, toBCommission, permit2 signature mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_permit2Signature() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE)  public {
        bytes memory swapData = _generateWETH2USDTSmartSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory permit2Info = _generatePermit2Info(WETH, 2 * 10 ** 18);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }


    // ==================== Internal Functions ====================
    function _generateWETH2USDTSmartSwapData(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapData(
            WETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0)),
            mode
        );
    }

    function _generateUSDT2WETHSmartSwapData(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapData(
            USDT,
            WETH,
            1000 * 10 ** 6,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(USDT, WETH, 0)),
            mode
        );
    }

    function _generateSmartSwapData(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        address assetTo,
        address adapter,
        bool isReverse,
        address poolAddress,
        bytes memory extraData,
        uint256 mode
    ) internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(fromToken, toToken, fromTokenAmount);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = fromTokenAmount;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = adapter;
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = assetTo;
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(isReverse ? 0x80 : 0x00), uint88(10000), poolAddress)));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = extraData;
        swapInfo.batches[0][0].fromToken = uint256(uint160(fromToken == ETH ? WETH : fromToken)) | mode;
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generatePermit2Info(
        address token,
        uint256 amount
    ) internal view returns (bytes memory) {
        IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
            token, // token
            amount, // amount
            2, // nonce
            2524579200 // deadline 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            11111111111111111111, // private key
            address(dexRouter), // spender
            Permit2EthDomainSeperator
        );

        bytes memory permit2Info = _buildPermit2InfoUnified(
            permit.permitted.amount,
            permit.nonce,
            permit.deadline,
            arnaud,
            signature
        );

        return permit2Info;
    }
}