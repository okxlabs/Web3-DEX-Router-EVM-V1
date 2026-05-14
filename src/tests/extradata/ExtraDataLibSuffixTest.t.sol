// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExtraDataLibTestBase.t.sol";

/// @title ExtraDataLibSuffixTest
/// @notice Verifies that ExtraDataLib still parses ExtraData correctly when an arbitrary
///         calldata suffix (e.g. ERC-8021 transaction-attribution data) has been appended
///         after ExtraData. The library locates the right edge of ExtraData via a 32-byte
///         aligned backward flag scan, so any unstructured trailing bytes are ignored.
///
/// Suffix variations covered:
///   - ERC-8021 Schema 0 (codes + length + schemaId + 16B ercMarker)
///   - Random bytes of arbitrary length (1B, 17B, 32B, 33B, 64B, 100B, 273B, 1024B)
///   - Suffixes that begin or end with bytes that look flag-like (false-positive guard)
///   - Suffixes that are exactly 32-byte aligned (alignment edge case)
contract ExtraDataLibSuffixTest is ExtraDataLibTestBase {

    bytes16 internal constant ERC8021_MARKER = 0x80218021802180218021802180218021;

    // ==================== Single-type ExtraData + suffix ====================

    /// @dev Commission only, every referrer count, every "interesting" suffix length.
    function test_suffix_commission_allReferrerCounts() public {
        uint256[8] memory suffixLens = [uint256(1), 17, 18, 32, 33, 64, 99, 273];
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            for (uint256 s = 0; s < suffixLens.length; s++) {
                bytes memory suffix = _buildRandomSuffix(suffixLens[s], i * 100 + s);
                bytes memory data = bytes.concat(swapData, commissionData, suffix);
                IDexRouter.ExtraData memory extraData = _callAndDecode(data);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertTrimInfoBeEmpty(extraData.trimInfo);
                _assertPermit2InfoBeEmpty(extraData.permit2Info);
                _assertRefundToBeEmpty(extraData.refundTo);
            }
        }
    }

    /// @dev Trim only — both onlyTrim (64B) and trim+charge (96B) variants.
    function test_suffix_trim_bothVariants() public {
        bytes memory trim64 = _generateTrimDataOnlyTrim();
        bytes memory trim96 = _generateTrimDataTrimAndCahrge();
        uint256[6] memory suffixLens = [uint256(7), 18, 32, 50, 273, 512];

        for (uint256 s = 0; s < suffixLens.length; s++) {
            bytes memory suffix = _buildRandomSuffix(suffixLens[s], s);

            // 64B trim
            IDexRouter.ExtraData memory ed = _callAndDecode(bytes.concat(swapData, trim64, suffix));
            _assertTrimInfo(ed.trimInfo, true);
            _assertCommissionInfoBeEmpty(ed.commissionInfo);

            // 96B trim+charge
            ed = _callAndDecode(bytes.concat(swapData, trim96, suffix));
            _assertTrimInfo(ed.trimInfo, false);
            _assertCommissionInfoBeEmpty(ed.commissionInfo);
        }
    }

    /// @dev Permit2 only — both 64B and 65B signatures, varying amount counts.
    function test_suffix_permit2_bothSignatureLengths() public {
        uint256[4] memory suffixLens = [uint256(18), 32, 64, 273];
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            bytes memory permit65 = _generatePermit2Data(i, signature65);
            bytes memory permit64 = _generatePermit2Data(i, signature64);
            for (uint256 s = 0; s < suffixLens.length; s++) {
                bytes memory suffix = _buildRandomSuffix(suffixLens[s], i + s);
                IDexRouter.ExtraData memory ed = _callAndDecode(bytes.concat(swapData, permit65, suffix));
                _assertPermit2Info(ed.permit2Info, i, signature65);
                ed = _callAndDecode(bytes.concat(swapData, permit64, suffix));
                _assertPermit2Info(ed.permit2Info, i, signature64);
            }
        }
    }

    /// @dev RefundTo only.
    function test_suffix_refundTo() public {
        bytes memory refundData = _generateRefundToData();
        uint256[5] memory suffixLens = [uint256(1), 18, 32, 33, 273];
        for (uint256 s = 0; s < suffixLens.length; s++) {
            bytes memory suffix = _buildRandomSuffix(suffixLens[s], s);
            IDexRouter.ExtraData memory ed = _callAndDecode(bytes.concat(swapData, refundData, suffix));
            _assertRefundTo(ed.refundTo);
            _assertCommissionInfoBeEmpty(ed.commissionInfo);
            _assertTrimInfoBeEmpty(ed.trimInfo);
            _assertPermit2InfoBeEmpty(ed.permit2Info);
        }
    }

    // ==================== No ExtraData + suffix ====================

    /// @dev When no ExtraData was sent, every parsed field must remain empty regardless of suffix.
    function test_suffix_noExtraData() public {
        uint256[7] memory suffixLens = [uint256(1), 17, 18, 32, 33, 273, 1024];
        for (uint256 s = 0; s < suffixLens.length; s++) {
            bytes memory suffix = _buildRandomSuffix(suffixLens[s], s + 7777);
            IDexRouter.ExtraData memory ed = _callAndDecode(bytes.concat(swapData, suffix));
            _assertCommissionInfoBeEmpty(ed.commissionInfo);
            _assertTrimInfoBeEmpty(ed.trimInfo);
            _assertPermit2InfoBeEmpty(ed.permit2Info);
            _assertRefundToBeEmpty(ed.refundTo);
        }
    }

    // ==================== Multi-type ExtraData + suffix ====================

    /// @dev Commission + trim, both trim variants, varying suffix lengths.
    function test_suffix_commissionAndTrim() public {
        uint256[3] memory suffixLens = [uint256(18), 64, 273];
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            for (uint256 s = 0; s < suffixLens.length; s++) {
                bytes memory suffix = _buildRandomSuffix(suffixLens[s], i + s);

                // onlyTrim
                bytes memory data = bytes.concat(swapData, _generateTrimDataOnlyTrim(), commissionData, suffix);
                IDexRouter.ExtraData memory ed = _callAndDecode(data);
                _assertCommissionInfo(ed.commissionInfo, i);
                _assertTrimInfo(ed.trimInfo, true);

                // trim + charge
                data = bytes.concat(swapData, _generateTrimDataTrimAndCahrge(), commissionData, suffix);
                ed = _callAndDecode(data);
                _assertCommissionInfo(ed.commissionInfo, i);
                _assertTrimInfo(ed.trimInfo, false);
            }
        }
    }

    /// @dev refundTo + permit2 + trim + commission (all four types), random suffix.
    function test_suffix_allTypes() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permitData = _generatePermit2Data(2, signature65);
        bytes memory refundData = _generateRefundToData();
        uint256[4] memory suffixLens = [uint256(18), 32, 100, 273];
        for (uint256 s = 0; s < suffixLens.length; s++) {
            bytes memory suffix = _buildRandomSuffix(suffixLens[s], 0xCAFE + s);
            bytes memory data = bytes.concat(swapData, refundData, permitData, trimData, commissionData, suffix);
            IDexRouter.ExtraData memory ed = _callAndDecode(data);
            _assertCommissionInfo(ed.commissionInfo, 1);
            _assertTrimInfo(ed.trimInfo, true);
            _assertPermit2Info(ed.permit2Info, 2, signature65);
            _assertRefundTo(ed.refundTo);
        }
    }

    // ==================== ERC-8021 Schema 0 specific ====================

    /// @dev Realistic ERC-8021 Schema 0 suffix (codes + 1B codesLength + 1B schemaId=0x00 + 16B marker).
    function test_suffix_erc8021Schema0_baseapp() public {
        bytes memory suffix = _buildERC8021Suffix("baseapp"); // 7B codes -> 25B suffix
        bytes memory commissionData = _generateCommissionData(2);
        bytes memory trimData = _generateTrimDataTrimAndCahrge();
        bytes memory data = bytes.concat(swapData, trimData, commissionData, suffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 2);
        _assertTrimInfo(ed.trimInfo, false);
    }

    /// @dev Maximum-length ERC-8021 Schema 0 suffix: 255B codes -> 273B total.
    function test_suffix_erc8021Schema0_maxLength() public {
        bytes memory codes = new bytes(255);
        for (uint256 i = 0; i < 255; i++) {
            codes[i] = bytes1(uint8(0x61 + (i % 26))); // a-z repeating
        }
        bytes memory suffix = abi.encodePacked(codes, uint8(255), uint8(0x00), ERC8021_MARKER);
        assertEq(suffix.length, 273, "ERC-8021 max suffix should be 273B");

        bytes memory commissionData = _generateCommissionData(8); // multi-commission worst case
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 8);
    }

    /// @dev ERC-8021 suffix together with no-ExtraData calldata.
    function test_suffix_erc8021Schema0_noExtraData() public {
        bytes memory suffix = _buildERC8021Suffix("okxapp");
        bytes memory data = bytes.concat(swapData, suffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfoBeEmpty(ed.commissionInfo);
        _assertTrimInfoBeEmpty(ed.trimInfo);
        _assertPermit2InfoBeEmpty(ed.permit2Info);
        _assertRefundToBeEmpty(ed.refundTo);
    }

    // ==================== Alignment edge cases ====================

    /// @dev Exactly 32-byte aligned suffix — `aligned` equals calldatasize, scan must walk one
    ///      step back to skip the suffix word and land on the real flag.
    function test_suffix_exactly32ByteAligned() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory suffix32 = _buildRandomSuffix(32, 0xA32);
        bytes memory data = bytes.concat(swapData, commissionData, suffix32);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 1);
    }

    /// @dev Multiples of 32 (64, 96, 128) — scan must walk two/three/four words back.
    function test_suffix_multipleOf32() public {
        bytes memory commissionData = _generateCommissionData(1);
        uint256[4] memory lens = [uint256(32), 64, 96, 128];
        for (uint256 s = 0; s < lens.length; s++) {
            bytes memory suffix = _buildRandomSuffix(lens[s], 0x32 * (s + 1));
            bytes memory data = bytes.concat(swapData, commissionData, suffix);
            IDexRouter.ExtraData memory ed = _callAndDecode(data);
            _assertCommissionInfo(ed.commissionInfo, 1);
        }
    }

    /// @dev 1B suffix — minimum non-zero suffix; alignment strips it cleanly.
    function test_suffix_oneByte() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory data = bytes.concat(swapData, commissionData, hex"42");
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 1);
    }

    /// @dev 31B suffix — strips back exactly one alignment unit.
    function test_suffix_31Bytes() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory data = bytes.concat(swapData, commissionData, _buildRandomSuffix(31, 31));
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 1);
    }

    // ==================== Long random suffixes ====================

    function test_suffix_long_512B() public {
        bytes memory suffix = _buildRandomSuffix(512, 0x512);
        bytes memory data = bytes.concat(swapData, _generateCommissionData(3), suffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 3);
    }

    function test_suffix_long_1024B() public {
        bytes memory suffix = _buildRandomSuffix(1024, 0x1024);
        bytes memory data = bytes.concat(swapData, _generateTrimDataOnlyTrim(), _generateCommissionData(1), suffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 1);
        _assertTrimInfo(ed.trimInfo, true);
    }

    // ==================== False-positive guard: suffix that contains flag-like bytes ====================

    /// @dev Suffix begins with a valid commission flag pattern at a NON-aligned position.
    ///      The 32-byte aligned scan must NOT match it, and must instead find the real
    ///      flag in actual ExtraData.
    function test_suffix_flagLikeBytes_atNonAlignedOffset() public {
        bytes memory commissionData = _generateCommissionData(1);

        // Build a suffix where the first 5 bytes are arbitrary, then the next 6 bytes spell
        // a real commission flag pattern. Because the suffix starts at position calldatasize -
        // suffix.length (rarely a 32-byte aligned position), the embedded flag will not fall on
        // an aligned word and the scan must skip it.
        bytes memory suffix = abi.encodePacked(
            hex"deadbeefca",                  // 5B noise
            bytes6(0x3ca20afc2aaa),           // 6B that looks like FROM_TOKEN_COMMISSION's high 6 bytes
            hex"00000000000000000000000000000000000000000000000000" // 25B zero padding
        );
        // Total suffix length: 5 + 6 + 25 = 36 bytes — non-multiple of 32 deliberately.
        bytes memory data = bytes.concat(swapData, commissionData, suffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 1);
    }

    /// @dev Suffix is sized so it leaves a 32-byte aligned residue containing flag-like bytes.
    ///      Even if a fake flag lands on an aligned position, the parser would either
    ///      mis-parse OR revert via boundary checks — but since real ExtraData sits to the LEFT
    ///      of the suffix, backward scan should hit the suffix flag FIRST.
    ///      This test documents that the parser may return garbage in that case but must
    ///      never silently drop real ExtraData with a "normal" suffix that doesn't fake flags.
    function test_suffix_doesNotDropRealExtraData_normalSuffix() public {
        bytes memory commissionData = _generateCommissionData(2); // dual commission, 96B
        bytes memory normalSuffix = hex"010203040506070809"; // 9B random non-flag
        bytes memory data = bytes.concat(swapData, commissionData, normalSuffix);
        IDexRouter.ExtraData memory ed = _callAndDecode(data);
        _assertCommissionInfo(ed.commissionInfo, 2);
    }

    // ==================== Scan lower bound: flag-like bytes inside swapData are ignored ====================
    // Note: the parser still reads `endPoint - 32` (the last word of swapData when there's no
    // ExtraData), so these tests place the fake flag in a NON-last word of swapData — the spot
    // where the swapDataLength-bounded scan differs from an unbounded scan.

    /// @dev 2-word `data`: fake commission flag in the first word, zero in the second.
    ///      The bounded scan never reads the first word; parser reads only the (zero) last word
    ///      and concludes there is no ExtraData.
    function test_swapDataFakeFlagIgnored_notInLastWord() public {
        bytes memory dataWithFakeFlag = abi.encodePacked(
            bytes32(0x3ca20afc2aaa00000000000000000000000000000000000000000000000000aa),
            bytes32(0)
        );
        bytes memory craftedSwapData = abi.encodeWithSelector(
            ExtraDataLibTestHelper.getExtraData.selector,
            dataWithFakeFlag
        );
        (bool success, bytes memory returnData) = address(extraDataLibTestHelper).call(craftedSwapData);
        require(success, "call must succeed: scan bound below swapDataLength ignores ABI-internal flag");
        IDexRouter.ExtraData memory ed = abi.decode(returnData, (IDexRouter.ExtraData));
        _assertCommissionInfoBeEmpty(ed.commissionInfo);
        _assertTrimInfoBeEmpty(ed.trimInfo);
        _assertPermit2InfoBeEmpty(ed.permit2Info);
        _assertRefundToBeEmpty(ed.refundTo);
    }

    /// @dev Fake TRIM_FLAG pattern in a non-last word of swapData, plus an ERC-8021 suffix.
    function test_swapDataFakeTrimFlagIgnored_withSuffix() public {
        bytes memory dataWithFakeFlag = abi.encodePacked(
            bytes32(0x7777777711110000000000000000000000000000000000000000000000000000),
            bytes32(0)
        );
        bytes memory craftedSwapData = abi.encodeWithSelector(
            ExtraDataLibTestHelper.getExtraData.selector,
            dataWithFakeFlag
        );
        bytes memory data = bytes.concat(craftedSwapData, _buildERC8021Suffix("baseapp"));
        (bool success, bytes memory returnData) = address(extraDataLibTestHelper).call(data);
        require(success, "call must succeed: ABI-internal fake trim flag must not be detected");
        IDexRouter.ExtraData memory ed = abi.decode(returnData, (IDexRouter.ExtraData));
        _assertCommissionInfoBeEmpty(ed.commissionInfo);
        _assertTrimInfoBeEmpty(ed.trimInfo);
    }

    /// @dev swapData contains a fake commission flag (non-last word) AND real ExtraData is
    ///      appended. The scan must find the real flag first (rightmost-wins) and parse it,
    ///      while never reaching the fake flag.
    function test_swapDataFakeFlag_realExtraDataStillParsed() public {
        bytes memory dataWithFakeFlag = abi.encodePacked(
            bytes32(0x3ca20afc2aaa00000000000000000000000000000000000000000000000000aa),
            bytes32(0)
        );
        bytes memory craftedSwapData = abi.encodeWithSelector(
            ExtraDataLibTestHelper.getExtraData.selector,
            dataWithFakeFlag
        );
        bytes memory realCommission = _generateCommissionData(2);
        bytes memory data = bytes.concat(craftedSwapData, realCommission);
        (bool success, bytes memory returnData) = address(extraDataLibTestHelper).call(data);
        require(success, "call must succeed: real ExtraData wins, fake ABI flag ignored");
        IDexRouter.ExtraData memory ed = abi.decode(returnData, (IDexRouter.ExtraData));
        _assertCommissionInfo(ed.commissionInfo, 2);
    }

    // ==================== Equivalence: suffix of given length must not change the result ====================

    /// @dev Property: for any commission count, parsing is identical with and without a suffix.
    function test_suffix_equivalence_commission() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory suffix = _buildERC8021Suffix("base");
            IDexRouter.ExtraData memory withSuffix =
                _callAndDecode(bytes.concat(swapData, commissionData, suffix));
            IDexRouter.ExtraData memory withoutSuffix =
                _callAndDecode(bytes.concat(swapData, commissionData));
            assertEq(
                keccak256(abi.encode(withSuffix.commissionInfo)),
                keccak256(abi.encode(withoutSuffix.commissionInfo)),
                "commissionInfo must match with/without suffix"
            );
        }
    }

    /// @dev Property: trim parsing is identical with and without a suffix.
    function test_suffix_equivalence_trim() public {
        bytes memory suffix = _buildERC8021Suffix("xtest");
        IDexRouter.ExtraData memory a =
            _callAndDecode(bytes.concat(swapData, _generateTrimDataTrimAndCahrge(), suffix));
        IDexRouter.ExtraData memory b =
            _callAndDecode(bytes.concat(swapData, _generateTrimDataTrimAndCahrge()));
        assertEq(
            keccak256(abi.encode(a.trimInfo)),
            keccak256(abi.encode(b.trimInfo)),
            "trimInfo must match with/without suffix"
        );
    }

    // ==================== Internal helpers ====================

    /// @dev Build a simulated ERC-8021 Schema 0 suffix:
    ///      `codes (variable ASCII) | codesLength (1B) | schemaId=0x00 (1B) | ercMarker (16B)`.
    /// @param code ASCII entity code (e.g. "baseapp"); must be <= 255 bytes.
    function _buildERC8021Suffix(string memory code) internal pure returns (bytes memory) {
        bytes memory codeBytes = bytes(code);
        require(codeBytes.length <= 255, "code too long");
        return abi.encodePacked(codeBytes, uint8(codeBytes.length), uint8(0x00), ERC8021_MARKER);
    }

    /// @dev Build an arbitrary-length deterministic-random suffix.
    function _buildRandomSuffix(uint256 length, uint256 seed) internal pure returns (bytes memory) {
        bytes memory suffix = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            suffix[i] = bytes1(uint8(uint256(keccak256(abi.encodePacked(seed, i))) % 256));
        }
        return suffix;
    }
}
