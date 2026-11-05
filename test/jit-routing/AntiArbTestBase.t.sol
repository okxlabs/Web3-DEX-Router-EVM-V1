// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "forge-std/Test.sol";

/// @title Shared harness for RFQ anti-arbitrage tests.
/// @notice Provides the authorization signer (derived via makeAddrAndKey — never hardcoded)
///         and EIP-191 + EIP-2098 compact-signature helpers matching CallerAuth's digest formulas, plus
///         the calldata-tail marker constants injected by CommonLib.exeAdapter.
abstract contract AntiArbTestBase is Test {
    // -- Tail markers (mirror Constants.sol; redeclared so tests need no ChainConfig dependency) --
    uint256 internal constant DEX_ROUTER_CALLER_MARKER =
        0x3ca20afc2ddd0000000000000000000000000000000000000000000000000000;
    uint256 internal constant ORIGIN_PAYER_MARKER =
        0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
    uint256 internal constant MARKER_MASK =
        0xffffffffffff0000000000000000000000000000000000000000000000000000;
    uint256 internal constant ADDRESS_MASK =
        0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    address internal authSigner;
    uint256 internal authSignerKey;

    function _setUpSigner() internal {
        (authSigner, authSignerKey) = makeAddrAndKey("authSigner");
    }

    // --------------------------- Signature helpers ---------------------------

    /// @dev EIP-191 prefix + vm.sign + EIP-2098 compaction. Returns a 64-byte sig.
    function _compactSign(bytes32 inner) internal view returns (bytes memory) {
        return _compactSignWith(authSignerKey, inner);
    }

    /// @dev Same as _compactSign but with an explicit key (for wrong-signer negative tests).
    function _compactSignWith(uint256 key, bytes32 inner) internal pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", inner));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        bytes32 vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
        return abi.encodePacked(r, vs);
    }

    /// @dev CallerAuth inner digest: keccak256(abi.encode(target, payloadHash, allowedCallers, nonce, chainid)).
    function _signCaller(
        address target,
        bytes32 payloadHash,
        address[] memory allowedCallers,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 inner = keccak256(abi.encode(target, payloadHash, allowedCallers, nonce, block.chainid));
        return _compactSign(inner);
    }

    /// @dev NativeAuth inner digest: keccak256(abi.encode(target, quoteEncoded, beneficiary,
    ///      allowedCallers, nonce, chainid)).
    function _signNative(
        address target,
        bytes memory quoteEncoded,
        address beneficiary,
        address[] memory allowedCallers,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes32 inner =
            keccak256(abi.encode(target, quoteEncoded, beneficiary, allowedCallers, nonce, block.chainid));
        return _compactSign(inner);
    }

    /// @dev Single-element allowedCallers array literal.
    function _one(address a) internal pure returns (address[] memory arr) {
        arr = new address[](1);
        arr[0] = a;
    }

    /// @dev Two-element allowedCallers array literal.
    function _two(address a, address b) internal pure returns (address[] memory arr) {
        arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
    }
}
