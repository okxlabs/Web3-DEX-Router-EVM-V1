// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

library ECDSA {
    // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
    // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
    // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
    // signatures from current libraries generate a unique signature with an s-value in the lower half order.
    //
    // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
    // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
    // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
    // these malleable signatures as well.
    uint256 private constant _S_BOUNDARY = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0 + 1;
    uint256 private constant _COMPACT_S_MASK = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint256 private constant _COMPACT_V_SHIFT = 255;

    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal view returns (address signer) {
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            if lt(s, _S_BOUNDARY) {
                let ptr := mload(0x40)

                mstore(ptr, hash)
                mstore(add(ptr, 0x20), v)
                mstore(add(ptr, 0x40), r)
                mstore(add(ptr, 0x60), s)
                mstore(0, 0)
                pop(staticcall(gas(), 0x1, ptr, 0x80, 0, 0x20))
                signer := mload(0)
            }
        }
    }

    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal view returns (address signer) {
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let s := and(vs, _COMPACT_S_MASK)
            if lt(s, _S_BOUNDARY) {
                let ptr := mload(0x40)

                mstore(ptr, hash)
                mstore(add(ptr, 0x20), add(27, shr(_COMPACT_V_SHIFT, vs)))
                mstore(add(ptr, 0x40), r)
                mstore(add(ptr, 0x60), s)
                mstore(0, 0)
                pop(staticcall(gas(), 0x1, ptr, 0x80, 0, 0x20))
                signer := mload(0)
            }
        }
    }

    /// @dev WARNING!!!
    /// There is a known signature malleability issue with two representations of signatures!
    /// Even though this function is able to verify both standard 65-byte and compact 64-byte EIP-2098 signatures
    /// one should never use raw signatures for any kind of invalidation logic in their code.
    /// As the standard and compact representations are interchangeable any invalidation logic that relies on
    /// signature uniqueness will get rekt.
    /// More info: https://github.com/OpenZeppelin/openzeppelin-contracts/security/advisories/GHSA-4h98-2769-gh6h
    function recover(bytes32 hash, bytes calldata signature) internal view returns (address signer) {
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)

            // memory[ptr:ptr+0x80] = (hash, v, r, s)
            switch signature.length
            case 65 {
                // memory[ptr+0x20:ptr+0x80] = (v, r, s)
                mstore(add(ptr, 0x20), byte(0, calldataload(add(signature.offset, 0x40))))
                calldatacopy(add(ptr, 0x40), signature.offset, 0x40)
            }
            case 64 {
                // memory[ptr+0x20:ptr+0x80] = (v, r, s)
                let vs := calldataload(add(signature.offset, 0x20))
                mstore(add(ptr, 0x20), add(27, shr(_COMPACT_V_SHIFT, vs)))
                calldatacopy(add(ptr, 0x40), signature.offset, 0x20)
                mstore(add(ptr, 0x60), and(vs, _COMPACT_S_MASK))
            }
            default { ptr := 0 }

            if ptr {
                if lt(mload(add(ptr, 0x60)), _S_BOUNDARY) {
                    // memory[ptr:ptr+0x20] = (hash)
                    mstore(ptr, hash)

                    mstore(0, 0)
                    pop(staticcall(gas(), 0x1, ptr, 0x80, 0, 0x20))
                    signer := mload(0)
                }
            }
        }
    }

    function recoverOrIsValidSignature(address signer, bytes32 hash, bytes calldata signature)
        internal
        view
        returns (bool success)
    {
        if (signer == address(0)) return false;
        if ((signature.length == 64 || signature.length == 65) && recover(hash, signature) == signer) {
            return true;
        }
        return isValidSignature(signer, hash, signature);
    }

    function recoverOrIsValidSignature(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool success)
    {
        if (signer == address(0)) return false;
        if (recover(hash, v, r, s) == signer) {
            return true;
        }
        return isValidSignature(signer, hash, v, r, s);
    }

    function recoverOrIsValidSignature(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool success)
    {
        if (signer == address(0)) return false;
        if (recover(hash, r, vs) == signer) {
            return true;
        }
        return isValidSignature(signer, hash, r, vs);
    }

    function recoverOrIsValidSignature65(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool success)
    {
        if (signer == address(0)) return false;
        if (recover(hash, r, vs) == signer) {
            return true;
        }
        return isValidSignature65(signer, hash, r, vs);
    }

    function isValidSignature(address signer, bytes32 hash, bytes calldata signature)
        internal
        view
        returns (bool success)
    {
        // (bool success, bytes memory data) = signer.staticcall(abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, signature));
        // return success && data.length >= 4 && abi.decode(data, (bytes4)) == IERC1271.isValidSignature.selector;
        bytes4 selector = IERC1271.isValidSignature.selector;
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x04), hash)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), signature.length)
            calldatacopy(add(ptr, 0x64), signature.offset, signature.length)
            if staticcall(gas(), signer, ptr, add(0x64, signature.length), 0, 0x20) {
                success := and(eq(selector, mload(0)), eq(returndatasize(), 0x20))
            }
        }
    }

    function isValidSignature(address signer, bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool success)
    {
        bytes4 selector = IERC1271.isValidSignature.selector;
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x04), hash)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 65)
            mstore(add(ptr, 0x64), r)
            mstore(add(ptr, 0x84), s)
            mstore8(add(ptr, 0xa4), v)
            if staticcall(gas(), signer, ptr, 0xa5, 0, 0x20) {
                success := and(eq(selector, mload(0)), eq(returndatasize(), 0x20))
            }
        }
    }

    function isValidSignature(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool success)
    {
        // (bool success, bytes memory data) = signer.staticcall(abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, abi.encodePacked(r, vs)));
        // return success && data.length >= 4 && abi.decode(data, (bytes4)) == IERC1271.isValidSignature.selector;
        bytes4 selector = IERC1271.isValidSignature.selector;
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x04), hash)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 64)
            mstore(add(ptr, 0x64), r)
            mstore(add(ptr, 0x84), vs)
            if staticcall(gas(), signer, ptr, 0xa4, 0, 0x20) {
                success := and(eq(selector, mload(0)), eq(returndatasize(), 0x20))
            }
        }
    }

    function isValidSignature65(address signer, bytes32 hash, bytes32 r, bytes32 vs)
        internal
        view
        returns (bool success)
    {
        // (bool success, bytes memory data) = signer.staticcall(abi.encodeWithSelector(IERC1271.isValidSignature.selector, hash, abi.encodePacked(r, vs & ~uint256(1 << 255), uint8(vs >> 255))));
        // return success && data.length >= 4 && abi.decode(data, (bytes4)) == IERC1271.isValidSignature.selector;
        bytes4 selector = IERC1271.isValidSignature.selector;
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)

            mstore(ptr, selector)
            mstore(add(ptr, 0x04), hash)
            mstore(add(ptr, 0x24), 0x40)
            mstore(add(ptr, 0x44), 65)
            mstore(add(ptr, 0x64), r)
            mstore(add(ptr, 0x84), and(vs, _COMPACT_S_MASK))
            mstore8(add(ptr, 0xa4), add(27, shr(_COMPACT_V_SHIFT, vs)))
            if staticcall(gas(), signer, ptr, 0xa5, 0, 0x20) {
                success := and(eq(selector, mload(0)), eq(returndatasize(), 0x20))
            }
        }
    }

    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 res) {
        // 32 is the length in bytes of hash, enforced by the type signature above
        // return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            mstore(0, 0x19457468657265756d205369676e6564204d6573736167653a0a333200000000) // "\x19Ethereum Signed Message:\n32"
            mstore(28, hash)
            res := keccak256(0, 60)
        }
    }

    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 res) {
        // return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)
            mstore(ptr, 0x1901000000000000000000000000000000000000000000000000000000000000) // "\x19\x01"
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            res := keccak256(ptr, 66)
        }
    }
}
