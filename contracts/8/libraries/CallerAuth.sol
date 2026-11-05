// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ECDSA.sol";
import "./Constants.sol";

/// @title CallerAuth
abstract contract CallerAuth {
    address public immutable AUTH_SIGNER;

    mapping(uint256 => uint256) private _callerAuthNonceBitmap;

    // =========================== Errors ===========================

    error AUTH_ZeroSigner();
    error AUTH_UntrustedCaller();
    error AUTH_BadAuthSig();
    error AUTH_BadSigLen();
    error AUTH_NonceUsed();

    constructor(address authSigner) {
        if (authSigner == address(0)) revert AUTH_ZeroSigner();
        AUTH_SIGNER = authSigner;
    }

    // =========================== Verification ===========================

    /// @notice Verify authorization for a payload hash.
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

    function _verifyAuthCommon(
        bytes32 inner,
        address[] memory allowedCallers,
        uint256 nonce,
        bytes memory authSig
    ) internal {
        if (authSig.length != 64) revert AUTH_BadSigLen();

        bytes32 r;
        bytes32 vs;
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

    function _isAllowedCaller(address[] memory allowedCallers) private view returns (bool) {
        uint256 len = allowedCallers.length;
        for (uint256 i; i < len; ++i) {
            if (allowedCallers[i] == msg.sender) return true;
        }
        return false;
    }

    function _useNonce(uint256 nonce) private {
        uint256 wordPos = nonce >> 8;
        uint256 bit = 1 << (nonce & 0xff);
        uint256 word = _callerAuthNonceBitmap[wordPos];
        if (word & bit != 0) revert AUTH_NonceUsed();
        _callerAuthNonceBitmap[wordPos] = word | bit;
    }

    /// @notice Return whether a nonce has been consumed.
    function isNonceUsed(uint256 nonce) external view returns (bool) {
        uint256 bit = 1 << (nonce & 0xff);
        return _callerAuthNonceBitmap[nonce >> 8] & bit != 0;
    }

    /// @dev Extract caller marker from the calldata tail.
    function _extractDexRouterCaller() internal pure returns (address dexRouterCaller) {
        assembly {
            let word := calldataload(sub(calldatasize(), 64))
            if eq(and(word, MARKER_MASK), DEX_ROUTER_CALLER_MARKER) {
                dexRouterCaller := and(word, _ADDRESS_MASK)
            }
        }
    }
}

/// @title NativeAuth
abstract contract NativeAuth is CallerAuth {
    constructor(address authSigner) CallerAuth(authSigner) {}

    /// @notice Verify authorization for a quote and beneficiary.
    function _verifyNativeAuth(
        bytes memory quoteEncoded,
        address beneficiary,
        address[] memory allowedCallers,
        uint256 nonce,
        bytes memory authSig
    ) internal {
        bytes32 inner = keccak256(
            abi.encode(
                address(this),
                quoteEncoded,
                beneficiary,
                allowedCallers,
                nonce,
                block.chainid
            )
        );
        _verifyAuthCommon(inner, allowedCallers, nonce, authSig);
    }
}
