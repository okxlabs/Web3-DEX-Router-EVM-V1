// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@dex/interfaces/IPermit2.sol";

contract Permit2Helper is Test {
    uint256 internal constant PERMIT2_INFO_SIG65_FLAG =
        0x92527fff1a650000000000000000000000000000000000000000000000000000; // bytes5(keccak256("Permit2Info")) + 0x65
    uint256 internal constant PERMIT2_INFO_SIG64_FLAG =
        0x92527fff1a640000000000000000000000000000000000000000000000000000; // bytes5(keccak256("Permit2Info")) + 0x64

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH =
        keccak256("TokenPermissions(address token,uint256 amount)");
    bytes32 public constant _PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    bytes32 public constant Permit2EthDomainSeperator = 0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28; // eth address: 0x000000000022D473030F116dDEE9F6B43aC78BA3


    /*  *NOTE* permit2Info encoded layout for permit2TransferFrom method
     *  For signature length 65, the encoded permit2Info should be like as follows, flag == bytes5(keccak256("Permit2Info")) + 0x65
     *  ┌────────────────┬────────────────┬────────────────┬─────────────┬──────────┬─────────────┬──────────┬─────────┬──────────────┬───────────┬───────────────┐
     *  │  signature_s   │  signature_r   │     amount     │ permit2_flag│ padding  │ signature_v │ deadline │ nonce   │ permit2_flag │  padding  │ owner_address │
     *  │  32 bytes      │  32 bytes      │    32 bytes    │ 6 bytes     │ 13 bytes │ 1 byte      │ 6 bytes  │ 6 bytes │ 6 bytes      │ 6 bytes   │ 20 bytes      │
     *  │                │                │                │0x92527fff1a65│         │             │          │         │0x92527fff1a65│           │               │
     *  └────────────────┴────────────────┴────────────────┴─────────────┴──────────┴─────────────┴──────────┴─────────┴──────────────┴───────────┴───────────────┘
     *   ←── 32 bytes ──→ ←── 32 bytes ──→ ←── 32 bytes ──→ ←─────────────────────── 32 bytes ────────────────────────→ ←─────────────── 32 bytes ───────────────→
     *
     *  For signature length 64, the encoded permit2Info should be like as follows, flag == bytes5(keccak256("Permit2Info")) + 0x64
     *  ┌────────────────┬────────────────┬────────────────┬─────────────┬────────────────────────┬──────────┬─────────┬──────────────┬───────────┬───────────────┐
     *  │  signature_s   │  signature_r   │     amount     │ permit2_flag│        padding         │ deadline │ nonce   │ permit2_flag │  padding  │ owner_address │
     *  │  32 bytes      │  32 bytes      │    32 bytes    │ 6 bytes     │        14 bytes        │ 6 bytes  │ 6 bytes │ 6 bytes      │ 6 bytes   │ 20 bytes      │
     *  │                │                │                │0x92527fff1a64│                       │          │         │0x92527fff1a64│           │               │
     *  └────────────────┴────────────────┴────────────────┴─────────────┴────────────────────────┴──────────┴─────────┴──────────────┴───────────┴───────────────┘
     *   ←── 32 bytes ──→ ←── 32 bytes ──→ ←── 32 bytes ──→ ←─────────────────────── 32 bytes ────────────────────────→ ←─────────────── 32 bytes ───────────────→
     *
     *
     *  *NOTE* permit2Info encoded layout for permit2TransferFrom method with array
     *  For signature length 65, the encoded permit2Info should be like as follows, flag == bytes5(keccak256("Permit2Info")) + 0x65
     *  ┌────────────────┬────────────────┬────────────────┬─────────────────┬────────────────┬─────────────┬──────────┬─────────────┬──────────┬─────────┬──────────────┬─────────────┬────────────┬───────────────┐
     *  │  amountN       │  amount2       │    amount1     │   signature_s   │   signature_r  │ permit2_flag│ padding  │ signature_v │ deadline │ nonce   │ permit2_flag │amount_length│ padding    │ owner_address │
     *  │  32 bytes      │  32 bytes      │    32 bytes    │   32 bytes      │   32 bytes     │ 6 bytes     │ 13 bytes │ 1 byte      │ 6 bytes  │ 6 bytes │ 6 bytes      │ 1 bytes     │ 5 bytes    │ 20 bytes      │
     *  │                │                │                │                 │                │0x92527fff1a65│         │             │          │         │0x92527fff1a65│             │            │               │
     *  └────────────────┴────────────────┴────────────────┴─────────────────┴────────────────┴─────────────┴──────────┴─────────────┴──────────┴─────────┴──────────────┴─────────────┴────────────┴───────────────┘
     *   ←─── 32 bytes ──→ ←── 32 bytes ─→ ←── 32 bytes ──→ ←─── 32 bytes ──→ ←── 32 bytes ──→ ←─────────────────────── 32 bytes ────────────────────────→ ←─────────────────────── 32 bytes ──────────────────────→
     *
     *  For signature length 64, the encoded permit2Info should be like as follows, flag == bytes5(keccak256("Permit2Info")) + 0x64
     *  ┌────────────────┬────────────────┬────────────────┬─────────────────┬────────────────┬─────────────┬────────────────────────┬──────────┬─────────┬──────────────┬─────────────┬────────────┬───────────────┐
     *  │  amountN       │  amount2       │    amount1     │   signature_s   │   signature_r  │ permit2_flag│        padding         │ deadline │ nonce   │ permit2_flag │amount_length│ padding    │ owner_address │
     *  │  32 bytes      │  32 bytes      │    32 bytes    │   32 bytes      │   32 bytes     │ 6 bytes     │        14 bytes        │ 6 bytes  │ 6 bytes │ 6 bytes      │ 1 bytes     │ 5 bytes    │ 20 bytes      │
     *  │                │                │                │                 │                │0x92527fff1a64│                       │          │         │0x92527fff1a64│             │            │               │
     *  └────────────────┴────────────────┴────────────────┴─────────────────┴────────────────┴─────────────┴────────────────────────┴──────────┴─────────┴──────────────┴─────────────┴────────────┴───────────────┘
     *   ←── 32 bytes ──→ ←── 32 bytes ──→ ←── 32 bytes ──→ ←── 32 bytes ───→ ←── 32 bytes ──→ ←──────────────────────── 32 bytes ───────────────────────→ ←───────────────────── 32 bytes ────────────────────────→
    */

    struct Permit2Info {
        IPermit2.PermitTransferFrom permit;
        address owner;
        bytes signature;
    }

    function _buildPermit2InfoUnified(
        uint256 maxAmount,
        uint256 nonce,
        uint256 deadline,
        address owner,
        bytes memory signature
    ) internal pure returns (bytes memory) {
        require(signature.length == 64 || signature.length == 65, "signature length must be 64 or 65");
        uint256 flag = signature.length == 65 ? PERMIT2_INFO_SIG65_FLAG : PERMIT2_INFO_SIG64_FLAG;

        // copy signature to permit2Info with 32 bytes chunks
        // signature memory layout:
        // signature + 0x00: the length of the signature
        // signature + 0x20: the first bytes32 of the signature (r)
        // signature + 0x40: the second bytes32 of the signature (s)
        // signature + 0x60: the last byte of the signature (v for length=65), and need to be shifted right 248 bits
        uint256 r;
        assembly {
            r := mload(add(signature, 0x20)) 
        }
        uint256 s;
        assembly {
            s := mload(add(signature, 0x40))
        }
        uint56 v;
        if (signature.length == 65) {
            assembly {
                v := shr(248, mload(add(signature, 0x60)))
            }
        }

        bytes memory permit2Info = abi.encodePacked(
            bytes32(s),
            bytes32(r),
            bytes32(uint256(maxAmount)),
            bytes32(
                (flag & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                (uint256(nonce) & 0x0000000000000000000000000000000000000000000000000000ffffffffffff) |
                ((uint256(deadline) << 48) & 0x0000000000000000000000000000000000000000ffffffffffff000000000000) |
                ((uint256(v) << 96) & 0x00000000000000000000000000000000000000ff000000000000000000000000)
            ),
            bytes32(
                (flag & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                uint256(uint160(owner)) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
            )
        );

        return permit2Info;
    }

    function getPermitTransferSignature(
        IPermit2.PermitTransferFrom memory permit,
        uint256 privateKey,
        address spender,
        bytes32 permit2DomainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2DomainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, spender, permit.nonce, permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitTransferFrom(
        address token,
        uint256 maxAmount,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (IPermit2.PermitTransferFrom memory permit) {
        permit = IPermit2.PermitTransferFrom({
            permitted: IPermit2.TokenPermissions({
                token: token,
                amount: maxAmount
            }),
            nonce: nonce,
            deadline: deadline
        });
    }

    function getPermitTransferDetails(
        address to,
        uint256 amount
    ) internal pure returns (IPermit2.SignatureTransferDetails memory transferDetails) {
        transferDetails = IPermit2.SignatureTransferDetails({
            to: to,
            requestedAmount: amount
        });
    }

    // // ==================== Public functions for testing ====================
    // function test_buildPermit2InfoUnified() public {
    //     IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
    //         0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH on eth
    //         1000000000000000000, // 1 WETH
    //         1,
    //         2524579200 // 2050-01-01 00:00:00
    //     );
    //     bytes memory signature = getPermitTransferSignature(
    //         permit,
    //         0x12341234, // private key
    //         0xF6801D319497789f934ec7F83E142a9536312B08, // spender
    //         Permit2EthDomainSeperator
    //     );
    //     // signature length: 65
    //     // signature = bytes.concat(r, s, bytes1(v));
    //     // signature: 0xad421a66bc11b9b3b3e4dfc6732c92d7f9361b51936d60a57b66033aaee098f7401ee7a49d784b2aaf04a5f1a06274c33d9d789471a2363131b01188c26da39b1c
    //     // r: 0xad421a66bc11b9b3b3e4dfc6732c92d7f9361b51936d60a57b66033aaee098f7
    //     // s: 0x401ee7a49d784b2aaf04a5f1a06274c33d9d789471a2363131b01188c26da39b
    //     // v: 28

    //     bytes memory permit2Info = _buildPermit2InfoUnified(
    //         permit.nonce,
    //         permit.deadline,
    //         permit.permitted.amount,
    //         vm.rememberKey(0x12341234), // 0xA229781d40864011729C753EAc24a772890fF527
    //         signature
    //     );
    //     console2.log("permit2Info length:", permit2Info.length);
    //     console2.log("permit2Info:");
    //     console2.logBytes(permit2Info);

    //     // smartSwap data without commission and trim
    //     bytes memory swapData = hex"03b87e5f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000d7ecaea56b618cde4af74b41131a00c96b814f69000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000de0b6b3a764000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000068ba4c4b00000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000048000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000001200000000000000000000000000000000000000000000000000000000000000160000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000010000000000000000000000006747bcaf9bd5a5f0758cbe08903490e45ddfacb500000000000000000000000000000000000000000000000000000000000000010000000000000000000000006747bcaf9bd5a5f0758cbe08903490e45ddfacb500000000000000000000000000000000000000000000000000000000000000010000000000000000000027104e68ccd3e89f51c3074ca5072bbac773960dfa360000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000060000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    //     console2.log("swapData length:", swapData.length);
    //     bytes memory swapDataWithPermit2Info = bytes.concat(swapData, permit2Info);
    //     console2.log("swapDataWithPermit2Info length:", swapDataWithPermit2Info.length);
    //     console2.log("swapDataWithPermit2Info:");
    //     console2.logBytes(swapDataWithPermit2Info);
    // }

    // function test_permit2InfoStructLayout() public {
    //     IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
    //         0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH on eth
    //         1000000000000000000, // 1 WETH
    //         1,
    //         2524579200 // 2050-01-01 00:00:00
    //     );
    //     bytes memory signature = getPermitTransferSignature(
    //         permit,
    //         0x12341234, // private key
    //         0xF6801D319497789f934ec7F83E142a9536312B08, // spender
    //         Permit2EthDomainSeperator
    //     );
    //     Permit2Info memory permit2Info = Permit2Info({
    //         permit: permit,
    //         owner: vm.rememberKey(0x12341234),
    //         signature: signature
    //     });
        
    //     // console value of permit2Info
    //     console2.log("permit2Info.permit.permitted.token:");
    //     console2.logBytes32(bytes32(uint256(uint160(permit2Info.permit.permitted.token))));
    //     console2.log("permit2Info.permit.permitted.amount:");
    //     console2.logBytes32(bytes32(permit2Info.permit.permitted.amount));
    //     console2.log("permit2Info.permit.nonce:");
    //     console2.logBytes32(bytes32(permit2Info.permit.nonce));
    //     console2.log("permit2Info.permit.deadline:");
    //     console2.logBytes32(bytes32(permit2Info.permit.deadline));
    //     console2.log("permit2Info.owner:");
    //     console2.logBytes32(bytes32(uint256(uint160(permit2Info.owner))));
    //     console2.log("permit2Info.signature:");
    //     console2.logBytes(permit2Info.signature);
    //     console2.log("--------------------------------");
        
    //     // console layout of permit2Info
    //     bytes32 slot0;
    //     bytes32 slot1;
    //     bytes32 slot2;
    //     bytes32 slot3;
    //     bytes32 slot4;
    //     bytes32 slot5;
    //     bytes32 slot6;
    //     bytes32 slot7;
    //     bytes32 slot8;
    //     bytes32 slot9;
    //     bytes32 slot10;
    //     bytes32 slot11;
    //     assembly {
    //         slot0 := mload(add(permit2Info, 0x00)) // permit2Info.permit position
    //         slot1 := mload(add(permit2Info, 0x20)) // permit2Info.owner value
    //         slot2 := mload(add(permit2Info, 0x40)) // permit2Info.signature position
    //         slot3 := mload(slot0) // permit2Info.permit.permitted position
    //         slot4 := mload(add(slot0, 0x20)) // permit2Info.permit.nonce
    //         slot5 := mload(add(slot0, 0x40)) // permit2Info.permit.deadline
    //         slot6 := mload(slot3) // permit2Info.permit.permitted.token
    //         slot7 := mload(add(slot3, 0x20)) // permit2Info.permit.permitted.amount
    //         slot8 := mload(slot2) // permit2Info.signature length
    //         slot9 := mload(add(slot2, 0x20)) // permit2Info.signature r
    //         slot10 := mload(add(slot2, 0x40)) // permit2Info.signature s
    //         slot11 := mload(add(slot2, 0x60)) // permit2Info.signature v (v is bytes1 at slot2 + 0x60)
    //     }
    //     console2.log("slot0 (permit2Info.permit position):");
    //     console2.logBytes32(slot0);
    //     console2.log("slot1 (permit2Info.owner value):");
    //     console2.logBytes32(slot1);
    //     console2.log("slot2 (permit2Info.signature position):");
    //     console2.logBytes32(slot2);
    //     console2.log("slot3 (permit2Info.permit.permitted position):");
    //     console2.logBytes32(slot3);
    //     console2.log("slot4 (permit2Info.permit.nonce):");
    //     console2.logBytes32(slot4);
    //     console2.log("slot5 (permit2Info.permit.deadline):");
    //     console2.logBytes32(slot5);
    //     console2.log("slot6 (permit2Info.permit.permitted.token):");
    //     console2.logBytes32(slot6);
    //     console2.log("slot7 (permit2Info.permit.permitted.amount):");
    //     console2.logBytes32(slot7);
    //     console2.log("slot8 (permit2Info.signature length):");
    //     console2.logBytes32(slot8);
    //     console2.log("slot9 (permit2Info.signature r):");
    //     console2.logBytes32(slot9);
    //     console2.log("slot10 (permit2Info.signature s):");
    //     console2.logBytes32(slot10);
    //     console2.log("slot11 (permit2Info.signature v (bytes1 at slot2 + 0x60)):");
    //     console2.logBytes32(slot11);
    // }
}