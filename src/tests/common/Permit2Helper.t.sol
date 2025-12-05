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
    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );
    bytes32 public constant Permit2EthDomainSeperator = 0x866a5aba21966af95d6c7ab78eb2b2fc913915c28be3b9aa07cc04ff903e3f28; // eth address: 0x000000000022D473030F116dDEE9F6B43aC78BA3


    /*  *NOTE* permit2Info encoded layout for permitTransferFrom method
     *  For signature length 65, the encoded permit2Info should be like as follows, flag == bytes5(keccak256("Permit2Info")) + 0x65
     *  ┌────────────────┬────────────────┬────────────────┬─────────────┬──────────┬─────────────┬──────────┬─────────┬──────────────┬───────────┬───────────────┐
     *  │  amount        │  signature_s   │  signature_r   │ permit2_flag│ padding  │ signature_v │ deadline │ nonce   │ permit2_flag │  padding  │ owner_address │
     *  │  32 bytes      │  32 bytes      │  32 bytes      │ 6 bytes     │ 13 bytes │ 1 byte      │ 6 bytes  │ 6 bytes │ 6 bytes      │ 6 bytes   │ 20 bytes      │
     *  │                │                │                │0x92527fff1a65│         │             │          │         │0x92527fff1a65│           │               │
     *  └────────────────┴────────────────┴────────────────┴─────────────┴──────────┴─────────────┴──────────┴─────────┴──────────────┴───────────┴───────────────┘
     *   ←── 32 bytes ──→ ←── 32 bytes ──→ ←── 32 bytes ──→ ←─────────────────────── 32 bytes ────────────────────────→ ←─────────────── 32 bytes ───────────────→
     *
     *  For signature length 64, the encoded permit2Info should be like as follows, flag == bytes5(keccak256("Permit2Info")) + 0x64
     *  ┌────────────────┬────────────────┬────────────────┬─────────────┬────────────────────────┬──────────┬─────────┬──────────────┬───────────┬───────────────┐
     *  │  amount        │  signature_s   │  signature_r   │ permit2_flag│        padding         │ deadline │ nonce   │ permit2_flag │  padding  │ owner_address │
     *  │  32 bytes      │  32 bytes      │  32 bytes      │ 6 bytes     │        14 bytes        │ 6 bytes  │ 6 bytes │ 6 bytes      │ 6 bytes   │ 20 bytes      │
     *  │                │                │                │0x92527fff1a64│                       │          │         │0x92527fff1a64│           │               │
     *  └────────────────┴────────────────┴────────────────┴─────────────┴────────────────────────┴──────────┴─────────┴──────────────┴───────────┴───────────────┘
     *   ←── 32 bytes ──→ ←── 32 bytes ──→ ←── 32 bytes ──→ ←─────────────────────── 32 bytes ────────────────────────→ ←─────────────── 32 bytes ───────────────→
     *
     *
     *  *NOTE* permit2Info encoded layout for permitTransferFrom method with array
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


    /// =============================== For permitTransferFrom without array ===============================
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
            bytes32(uint256(maxAmount)),
            bytes32(s),
            bytes32(r),
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

    /// =============================== For permitTransferFrom with array ===============================
    function _buildPermit2InfoUnified(
        uint256[] memory maxAmounts,
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

        uint256 maxAmountsLength = maxAmounts.length;

        bytes memory permit2Info = abi.encodePacked(
            bytes32(s),
            bytes32(r),
            bytes32(
                (flag & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                (uint256(nonce) & 0x0000000000000000000000000000000000000000000000000000ffffffffffff) |
                ((uint256(deadline) << 48) & 0x0000000000000000000000000000000000000000ffffffffffff000000000000) |
                ((uint256(v) << 96) & 0x00000000000000000000000000000000000000ff000000000000000000000000)
            ),
            bytes32(
                (flag & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                (maxAmountsLength & 0x000000000000ff00000000000000000000000000000000000000000000000000) |
                uint256(uint160(owner)) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
            )
        );

        for (uint256 i = 0; i < maxAmountsLength; i++) {
            permit2Info = abi.encodePacked(bytes32(maxAmounts[i]), permit2Info);
        }

        return permit2Info;
    }

    function getPermitBatchTransferSignature(
        IPermit2.PermitBatchTransferFrom memory permit,
        uint256 privateKey,
        address spender,
        bytes32 permit2DomainSeparator
    ) internal view returns (bytes memory sig) {
        bytes32[] memory tokenPermissions = new bytes32[](permit.permitted.length);
        for (uint256 i = 0; i < permit.permitted.length; ++i) {
            tokenPermissions[i] = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted[i]));
        }
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2DomainSeparator,
                keccak256(
                    abi.encode(
                        _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH,
                        keccak256(abi.encodePacked(tokenPermissions)),
                        spender,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getPermitBatchTransferFrom(
        address token,
        uint256[] memory maxAmounts,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (IPermit2.PermitBatchTransferFrom memory permit) {
        permit = IPermit2.PermitBatchTransferFrom({
            permitted: new IPermit2.TokenPermissions[](maxAmounts.length),
            nonce: nonce,
            deadline: deadline
        });
        for (uint256 i = 0; i < maxAmounts.length; i++) {
            permit.permitted[i] = IPermit2.TokenPermissions({
                token: token,
                amount: maxAmounts[i]
            });
        }
        return permit;
    }

    function getPermitBatchTransferDetails(
        address[] memory tos,
        uint256[] memory amounts
    ) internal pure returns (IPermit2.SignatureTransferDetails[] memory transferDetails) {
        require(tos.length == amounts.length, "tos and amounts length mismatch");
        transferDetails = new IPermit2.SignatureTransferDetails[](tos.length);
        for (uint256 i = 0; i < tos.length; i++) {
            transferDetails[i] = IPermit2.SignatureTransferDetails({
                to: tos[i],
                requestedAmount: amounts[i]
            });
        }
        return transferDetails;
    }
}