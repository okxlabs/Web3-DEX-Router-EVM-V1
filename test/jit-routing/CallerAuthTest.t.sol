// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "./AntiArbTestBase.t.sol";
import {CallerAuth, NativeAuth} from "@dex/libraries/CallerAuth.sol";

/// @dev Concrete harness exposing CallerAuth's internal verification for direct testing.
contract CallerAuthHarness is CallerAuth {
    constructor(address signer) CallerAuth(signer) {}

    function verifyCaller(
        bytes32 payloadHash,
        address[] memory allowedCallers,
        uint256 nonce,
        bytes memory sig
    ) external {
        _verifyCallerAuth(payloadHash, allowedCallers, nonce, sig);
    }
}

/// @dev Concrete harness exposing NativeAuth's quote+beneficiary-bound verification.
contract NativeAuthHarness is NativeAuth {
    constructor(address signer) NativeAuth(signer) {}

    function verifyNative(
        bytes memory quoteEncoded,
        address beneficiary,
        address[] memory allowedCallers,
        uint256 nonce,
        bytes memory sig
    ) external {
        _verifyNativeAuth(quoteEncoded, beneficiary, allowedCallers, nonce, sig);
    }
}

/// @title CallerAuth authorization tests.
/// @notice Covers caller, nonce, signer, domain, quote, and beneficiary binding.
contract CallerAuthTest is AntiArbTestBase {
    bytes32 internal constant PAYLOAD_HASH = bytes32(uint256(0x1234));

    CallerAuthHarness internal auth;
    NativeAuthHarness internal nativeAuth;

    function setUp() public {
        _setUpSigner();
        auth = new CallerAuthHarness(authSigner);
        nativeAuth = new NativeAuthHarness(authSigner);
    }

    // ---------------------- Happy path + nonce ----------------------

    /// Baseline: valid caller + valid signature + fresh nonce -> succeeds, nonce marked used.
    function test_valid_authorization_succeeds() public {
        address[] memory ac = _one(address(this));
        bytes memory sig = _signCaller(address(auth), PAYLOAD_HASH, ac, 1);
        assertFalse(auth.isNonceUsed(1), "nonce should start unused");
        auth.verifyCaller(PAYLOAD_HASH, ac, 1, sig);
        assertTrue(auth.isNonceUsed(1), "nonce must be consumed after success");
    }

    /// Replaying the same nonce reverts AUTH_NonceUsed.
    function test_nonce_reuse_reverts() public {
        address[] memory ac = _one(address(this));
        bytes memory sig = _signCaller(address(auth), PAYLOAD_HASH, ac, 7);
        auth.verifyCaller(PAYLOAD_HASH, ac, 7, sig);

        vm.expectRevert(CallerAuth.AUTH_NonceUsed.selector);
        auth.verifyCaller(PAYLOAD_HASH, ac, 7, sig);
    }

    // ---------------------- Untrusted caller ----------------------

    /// msg.sender not in allowedCallers reverts AUTH_UntrustedCaller (sig is otherwise valid).
    function test_untrusted_caller_reverts() public {
        address other = address(0xD00D);
        address[] memory ac = _one(other); // signed for `other`, but this contract calls
        bytes memory sig = _signCaller(address(auth), PAYLOAD_HASH, ac, 1);

        vm.expectRevert(CallerAuth.AUTH_UntrustedCaller.selector);
        auth.verifyCaller(PAYLOAD_HASH, ac, 1, sig);
    }

    /// An allowedCallers set with multiple entries admits each member.
    function test_multi_member_allowedCallers() public {
        address relayerA = address(0xA11CE);
        address relayerB = address(0xB0B);
        address[] memory ac = _two(relayerA, relayerB);

        bytes memory sigA = _signCaller(address(auth), PAYLOAD_HASH, ac, 1);
        vm.prank(relayerA);
        auth.verifyCaller(PAYLOAD_HASH, ac, 1, sigA);

        bytes memory sigB = _signCaller(address(auth), PAYLOAD_HASH, ac, 2);
        vm.prank(relayerB);
        auth.verifyCaller(PAYLOAD_HASH, ac, 2, sigB);

        // An address outside the set is still rejected.
        bytes memory sigC = _signCaller(address(auth), PAYLOAD_HASH, ac, 3);
        vm.prank(address(0xC0DE));
        vm.expectRevert(CallerAuth.AUTH_UntrustedCaller.selector);
        auth.verifyCaller(PAYLOAD_HASH, ac, 3, sigC);
    }

    // ---------------------- Bad authorization signature ----------------------

    /// A signature from an unauthorized key is rejected AUTH_BadAuthSig.
    function test_wrong_signer_reverts() public {
        (, uint256 attackerKey) = makeAddrAndKey("attacker");
        address[] memory ac = _one(address(this));
        bytes32 inner = keccak256(abi.encode(address(auth), PAYLOAD_HASH, ac, uint256(1), block.chainid));
        bytes memory badSig = _compactSignWith(attackerKey, inner);

        vm.expectRevert(CallerAuth.AUTH_BadAuthSig.selector);
        auth.verifyCaller(PAYLOAD_HASH, ac, 1, badSig);
    }

    /// Tampering with the bound payload hash after signing breaks the digest -> AUTH_BadAuthSig.
    function test_payload_hash_tamper_reverts() public {
        address[] memory ac = _one(address(this));
        bytes memory sig = _signCaller(address(auth), PAYLOAD_HASH, ac, 1);

        vm.expectRevert(CallerAuth.AUTH_BadAuthSig.selector);
        auth.verifyCaller(bytes32(uint256(0xBEEF)), ac, 1, sig);
    }

    // ---------------------- Signature length ----------------------

    /// A 65-byte (non-EIP-2098) signature reverts AUTH_BadSigLen.
    function test_bad_sig_length_reverts() public {
        address[] memory ac = _one(address(this));
        bytes memory sig65 = new bytes(65); // wrong length; checked first
        vm.expectRevert(CallerAuth.AUTH_BadSigLen.selector);
        auth.verifyCaller(PAYLOAD_HASH, ac, 1, sig65);
    }

    // ---------------------- Zero signer at deploy ----------------------

    /// Deploying with a zero authorization signer reverts AUTH_ZeroSigner (fail-closed).
    function test_zero_signer_deploy_reverts() public {
        vm.expectRevert(CallerAuth.AUTH_ZeroSigner.selector);
        new CallerAuthHarness(address(0));
    }

    // ---------------------- Cross-contract replay ----------------------

    /// A signature bound to contract A cannot be replayed on contract B (digest binds address(this)).
    function test_cross_contract_replay_reverts() public {
        CallerAuthHarness authB = new CallerAuthHarness(authSigner);
        address[] memory ac = _one(address(this));
        // Signed for `auth` (contract A), replayed on `authB` (contract B).
        bytes memory sig = _signCaller(address(auth), PAYLOAD_HASH, ac, 1);

        vm.expectRevert(CallerAuth.AUTH_BadAuthSig.selector);
        authB.verifyCaller(PAYLOAD_HASH, ac, 1, sig);
    }

    // ---------------------- Cross-chain replay ----------------------

    /// A signature bound to chainId X cannot be replayed on chainId Y (digest binds block.chainid).
    function test_cross_chain_replay_reverts() public {
        address[] memory ac = _one(address(this));
        bytes memory sig = _signCaller(address(auth), PAYLOAD_HASH, ac, 1); // signed at current chainid

        vm.chainId(block.chainid + 1); // move to a different chain
        vm.expectRevert(CallerAuth.AUTH_BadAuthSig.selector);
        auth.verifyCaller(PAYLOAD_HASH, ac, 1, sig);
    }

    // ---------------------- NativeAuth: quote + beneficiary binding ----------------------

    /// NativeAuth binds quoteEncoded + beneficiary: a valid tuple succeeds.
    function test_native_auth_valid_succeeds() public {
        bytes memory quoteEncoded = abi.encode("quote-blob");
        address beneficiary = address(0xBEEF);
        address[] memory ac = _one(address(this));
        bytes memory sig = _signNative(address(nativeAuth), quoteEncoded, beneficiary, ac, 1);
        nativeAuth.verifyNative(quoteEncoded, beneficiary, ac, 1, sig);
        assertTrue(nativeAuth.isNonceUsed(1), "native nonce consumed");
    }

    /// Tampering with the beneficiary after signing breaks the digest -> AUTH_BadAuthSig.
    function test_native_auth_beneficiary_tamper_reverts() public {
        bytes memory quoteEncoded = abi.encode("quote-blob");
        address[] memory ac = _one(address(this));
        bytes memory sig = _signNative(address(nativeAuth), quoteEncoded, address(0xBEEF), ac, 1);

        vm.expectRevert(CallerAuth.AUTH_BadAuthSig.selector);
        nativeAuth.verifyNative(quoteEncoded, address(0xBAD), ac, 1, sig); // different beneficiary
    }

    /// Tampering with the quote payload after signing breaks the digest -> AUTH_BadAuthSig.
    function test_native_auth_quote_tamper_reverts() public {
        address beneficiary = address(0xBEEF);
        address[] memory ac = _one(address(this));
        bytes memory sig = _signNative(address(nativeAuth), abi.encode("quote-A"), beneficiary, ac, 1);

        vm.expectRevert(CallerAuth.AUTH_BadAuthSig.selector);
        nativeAuth.verifyNative(abi.encode("quote-B"), beneficiary, ac, 1, sig); // different quote
    }
}
