// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ECDSA.sol";
import "./Constants.sol";

/// @dev Shared authorization helper for payload-scoped caller checks.
abstract contract CallerAuth {
    /// @dev Authorization signer fixed at deployment.
    address public immutable AUTH_SIGNER;

    /// @dev wordPos => nonce bitmap, where wordPos = nonce >> 8.
    mapping(uint256 => uint256) private _callerAuthNonceBitmap;

    // =========================== Errors ===========================

    error AUTH_ZeroSigner();
    error AUTH_UntrustedCaller();
    error AUTH_BadCallersLength();
    error AUTH_BadAuthSig();
    error AUTH_BadSigLen();
    error AUTH_NonceUsed();

    constructor(address authSigner) {
        if (authSigner == address(0)) revert AUTH_ZeroSigner();
        AUTH_SIGNER = authSigner;
    }

    // =========================== Verification ===========================

    /// @dev Verifies `keccak256(abi.encode(address(this), payloadHash, allowedCallers, nonce, block.chainid))`.
    function _verifyCallerAuth(
        bytes32 payloadHash,
        address[] memory allowedCallers,
        uint256 nonce,
        bytes memory authSig
    ) internal {
        bytes32 inner = keccak256(
            abi.encode(address(this), payloadHash, allowedCallers, nonce, block.chainid)
        );
        _verifyAuthCommon(inner, allowedCallers, nonce, authSig);
    }

    /// @dev Accepts only 64-byte EIP-2098 compact signatures.
    function _verifyAuthCommon(
        bytes32 inner,
        address[] memory allowedCallers,
        uint256 nonce,
        bytes memory authSig
    ) internal {
        if (authSig.length != 64) revert AUTH_BadSigLen();

        bytes32 r;
        bytes32 vs;
        /// @solidity memory-safe-assembly
        assembly {
            r := mload(add(authSig, 0x20))
            vs := mload(add(authSig, 0x40))
        }

        bytes32 digest = ECDSA.toEthSignedMessageHash(inner);
        address signer = ECDSA.recover(digest, r, vs);
        if (signer != AUTH_SIGNER) revert AUTH_BadAuthSig();

        if (!_isAllowedCaller(allowedCallers)) revert AUTH_UntrustedCaller();

        _useNonce(nonce);
    }

    // =========================== Internal helpers ===========================

    /// @dev Checks whether msg.sender is included in the signed caller set.
    function _isAllowedCaller(address[] memory allowedCallers) private view returns (bool) {
        uint256 len = allowedCallers.length;
        for (uint256 i; i < len; ++i) {
            if (allowedCallers[i] == msg.sender) return true;
        }
        return false;
    }

    /// @dev Consumes a nonce bit and reverts if it was already used.
    function _useNonce(uint256 nonce) private {
        uint256 wordPos = nonce >> 8;
        uint256 bit = 1 << (nonce & 0xff);
        uint256 word = _callerAuthNonceBitmap[wordPos];
        if (word & bit != 0) revert AUTH_NonceUsed();
        _callerAuthNonceBitmap[wordPos] = word | bit;
    }

    /// @dev Exposes nonce state for tests and off-chain reads.
    function isNonceUsed(uint256 nonce) external view returns (bool) {
        uint256 bit = 1 << (nonce & 0xff);
        return _callerAuthNonceBitmap[nonce >> 8] & bit != 0;
    }

    /// @dev Returns the address embedded in the -64 calldata word when its marker matches exactly.
    function _extractDexRouterCaller() internal pure returns (address dexRouterCaller) {
        /// @solidity memory-safe-assembly
        assembly {
            let word := calldataload(sub(calldatasize(), 64))
            if eq(and(word, MARKER_MASK), DEX_ROUTER_CALLER_MARKER) {
                dexRouterCaller := and(word, _ADDRESS_MASK)
            }
        }
    }
}
