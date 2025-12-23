/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// =============================================================================
// ============================ ETH Address Constants ==========================
// =============================================================================
address constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

// =============================================================================
// ======================= Universal Masks And Flags ===========================
// =============================================================================
uint256 constant _ADDRESS_MASK =
    0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
uint256 constant _REVERSE_MASK =
    0x8000000000000000000000000000000000000000000000000000000000000000;
uint256 constant _ORDER_ID_MASK =
    0xffffffffffffffffffffffff0000000000000000000000000000000000000000;
uint256 constant _WEIGHT_MASK =
    0x00000000000000000000ffff0000000000000000000000000000000000000000;
uint256 constant _CALL_GAS_LIMIT = 5000;
uint256 constant ORIGIN_PAYER =
    0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
uint256 constant SWAP_AMOUNT =
    0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;
uint256 constant _WETH_MASK =
    0x4000000000000000000000000000000000000000000000000000000000000000;
uint256 constant _ONE_FOR_ZERO_MASK = 1 << 255; // Mask for identifying if the swap is one-for-zero
uint256 constant _WETH_UNWRAP_MASK = 1 << 253; // Mask for identifying if WETH should be unwrapped to ETH

// =============================================================================
// ===================== Transfer Mode Masks and Flags =========================
// =============================================================================
uint256 constant _MODE_LEGACY =
    0x0000000000000000000000000000000000000000000000000000000000000000; // 0b000 in [bit251, bit250, bit249]
uint256 constant _MODE_PERMIT2_ALLOWANCE =
    0x0200000000000000000000000000000000000000000000000000000000000000; // 0b001 in [bit251, bit250, bit249]
uint256 constant _MODE_PERMIT2_SIGNATURE =
    0x0600000000000000000000000000000000000000000000000000000000000000; // 0b011 in [bit251, bit250, bit249]
uint256 constant _MODE_BY_INVEST =
    0x0400000000000000000000000000000000000000000000000000000000000000; // 0b010 in [bit251, bit250, bit249]
uint256 constant _MODE_NO_TRANSFER =
    0x0800000000000000000000000000000000000000000000000000000000000000; // 0b100 in [bit251, bit250, bit249]
uint256 constant _MODE_DIRECT =
    0x0A00000000000000000000000000000000000000000000000000000000000000; // 0b101 in [bit251, bit250, bit249]
uint256 constant _TRANSFER_MODE_MASK =
    0x0E00000000000000000000000000000000000000000000000000000000000000; // 0b111 in [bit251, bit250, bit249]

// =============================================================================
// ============================== DAG Swap Masks ===============================
// =============================================================================
uint256 constant _INPUT_INDEX_MASK =
    0x0000000000000000ff0000000000000000000000000000000000000000000000;
uint256 constant _OUTPUT_INDEX_MASK =
    0x000000000000000000ff00000000000000000000000000000000000000000000;

// =============================================================================
// ======================= Commission Masks and Flags ==========================
// =============================================================================
uint256 constant _COMMISSION_RATE_MASK =
    0x000000000000ffffffffffff0000000000000000000000000000000000000000;
uint256 constant _COMMISSION_FLAG_MASK =
    0xffffffffffff0000000000000000000000000000000000000000000000000000;
uint256 constant FROM_TOKEN_COMMISSION =
    0x3ca20afc2aaa0000000000000000000000000000000000000000000000000000;
uint256 constant TO_TOKEN_COMMISSION =
    0x3ca20afc2bbb0000000000000000000000000000000000000000000000000000;
uint256 constant FROM_TOKEN_COMMISSION_DUAL =
    0x22220afc2aaa0000000000000000000000000000000000000000000000000000;
uint256 constant TO_TOKEN_COMMISSION_DUAL =
    0x22220afc2bbb0000000000000000000000000000000000000000000000000000;
uint256 constant FROM_TOKEN_COMMISSION_MULTIPLE =
    0x88880afc2aaa0000000000000000000000000000000000000000000000000000;
uint256 constant TO_TOKEN_COMMISSION_MULTIPLE =
    0x88880afc2bbb0000000000000000000000000000000000000000000000000000;
uint256 constant _COMMISSION_LENGTH_MASK =
    0x00ff000000000000000000000000000000000000000000000000000000000000;
uint256 constant _TO_B_COMMISSION_MASK =
    0x8000000000000000000000000000000000000000000000000000000000000000;

// =============================================================================
// ============================= Trim Masks and Flags ==========================
// =============================================================================
uint256 constant _TRIM_FLAG_MASK =
    0xffffffffffff0000000000000000000000000000000000000000000000000000;
uint256 constant _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK =
    0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
uint256 constant _TRIM_RATE_MASK =
    0x000000000000ffffffffffff0000000000000000000000000000000000000000;
uint256 constant _TO_B_TRIM_MASK =
    0x0000000000008000000000000000000000000000000000000000000000000000;
uint256 constant TRIM_FLAG =
    0x7777777711110000000000000000000000000000000000000000000000000000;
uint256 constant TRIM_DUAL_FLAG =
    0x7777777722220000000000000000000000000000000000000000000000000000;

// =============================================================================
// ======================== Permit2 Info Masks and Flags =======================
// =============================================================================
uint256 constant _PERMIT2_INFO_FLAG_MASK =
    0xffffffffffff0000000000000000000000000000000000000000000000000000;
uint256 constant _PERMIT2_INFO_AMOUNT_LENGTH_MASK =
    0x000000000000ff00000000000000000000000000000000000000000000000000;
uint256 constant _PERMIT2_INFO_NONCE_MASK =
    0x0000000000000000000000000000000000000000000000000000ffffffffffff;
uint256 constant _PERMIT2_INFO_DEADLINE_MASK =
    0x0000000000000000000000000000000000000000ffffffffffff000000000000;
uint256 constant _PERMIT2_INFO_SIGNATURE_V_MASK =
    0x00000000000000000000000000000000000000ff000000000000000000000000;
uint256 constant PERMIT2_INFO_SIG65_FLAG =
    0x92527fff1a650000000000000000000000000000000000000000000000000000; // bytes5(keccak256("Permit2Info")) + 0x65
uint256 constant PERMIT2_INFO_SIG64_FLAG =
    0x92527fff1a640000000000000000000000000000000000000000000000000000; // bytes5(keccak256("Permit2Info")) + 0x64

// =============================================================================
// ============================= RefundTo Masks and Flags ======================
// =============================================================================
uint256 constant _REFUND_TO_MASK =
    0xffffffffffff0000000000000000000000000000000000000000000000000000;
uint256 constant REFUND_TO_ADDRESS_FLAG =
    0xac3a7da8b1c60000000000000000000000000000000000000000000000000000; // bytes6(keccak256("RefundTo"))

// =============================================================================
// ============================= Universal Values ==============================
// =============================================================================
uint256 constant MIN_COMMISSION_MULTIPLE_NUM = 3; // min referrer num for multiple commission
uint256 constant MAX_COMMISSION_MULTIPLE_NUM = 8; // max referrer num for multiple commission
uint256 constant COMMISSION_RATE_LIMIT = 10000000;
uint256 constant DENOMINATOR = 10 ** 9;
uint256 constant NO_TO_B_MODE = 1; // value for no-toB commission and no-toB trim when related calldata exists
uint256 constant TO_B_MODE = 2; // value for toB commission and toB trim when related calldata exists
uint256 constant WAD = 1 * 10 ** 18;
uint256 constant TRIM_RATE_LIMIT = 100;
uint256 constant TRIM_DENOMINATOR = 1000;

// =============================================================================
// ==================== Network-Specific Addresses =============================
// =============================================================================
// NOTE: These addresses need to be changed before deployment to different networks
address constant _WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant _APPROVE_PROXY = 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
address constant _WNATIVE_RELAY = 0x5703B683c7F928b721CA95Da988d73a3299d4757;
address constant _PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
