// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "../interfaces/IDexRouter.sol";
import "./EventLib.sol";

/*
 * To decode extra data encoded in calldata and parse to structs
 *
 * The extra data is appended after swapData in calldata, and parsed from the end (right to left).
 * All extra data fields are optional and can be omitted if not needed.
 *
 * Calldata Layout (from left to right):
 * ┌──────────┬────────┬──────────┬────────────┬──────────┬────────────┬────────────┐
 * │ swapData │ (memo) │ refundTo │ permit2Info│ trimInfo │ commission │ raw suffix │
 * │ N bytes  │ opt.   │  0/32 B  │   0/M B    │ 0/64/96 B│   0/K B    │  (0..N B)  │
 * └──────────┴────────┴──────────┴────────────┴──────────┴────────────┴────────────┘
 *                      ←─── Extra Data (anchored at endPoints[0]) ───→↑            ↑
 *                                                               endPoints[0]  calldatasize()
 *
 *   - `raw suffix` unstructured trailing bytes (e.g. ERC-8021 transaction-attribution data) that
 *                  may be appended by wallets, aggregators, or front-ends. The scan ignores them.
 *
 * Parsing Order (from right to left, anchored at endPoints[0]):
 * 1. commissionInfo  - Commission/referrer fee configuration (0, 64, 96, or more bytes depending on referrer count)
 * 2. trimInfo        - Trim/surplus handling configuration (0, 64, or 96 bytes)
 * 3. permit2Info     - Permit2 signature data for token approval (0 or variable bytes)
 * 4. refundTo        - Address to receive leftover tokens only for ByInvest mode (0 or 32 bytes)
*/

library ExtraDataLib {
    /// @dev Update EXTRA_DATA_TYPE_NUM when adding new extra calldata
    uint8 internal constant EXTRA_DATA_TYPE_NUM = 4;

    /// @notice Decode extra data and get structs with swapData boundary check
    /// @param swapDataLength The length of swapData (4 bytes selector + ABI encoded parameters)
    function getDecodedExtraData(uint256 swapDataLength) internal view returns (IDexRouter.ExtraData memory extraData) {
        // calldatasize() may extend past the real ExtraData when an external suffix
        // (e.g. ERC-8021 attribution data) has been appended. _getExtraDataEndPointAndLength
        // performs a 32-byte aligned backward scan, bounded below by swapDataLength, to recover
        // the true right edge and writes it into endPoints[0], which then anchors all subsequent
        // parsing.
        (uint256[] memory endPoints, uint256[] memory lengths) = _getExtraDataEndPointAndLength(swapDataLength);

        // Validate extraData boundaries against the swapData lower bound.
        _validateExtraDataBoundaries(endPoints, lengths, swapDataLength);

        extraData = IDexRouter.ExtraData({
            commissionInfo: _parseCommissionInfo(endPoints[0], lengths[0]),
            trimInfo: _parseTrimInfo(endPoints[1], lengths[1]),
            permit2Info: _parsePermit2Info(endPoints[2], lengths[2]),
            refundTo: _parseRefundTo(endPoints[3], lengths[3])
        });

        return extraData;
    }

    // ================================ Private Functions ================================
    /// @notice Get endPoints and lengths of each extra calldata bytes32.
    /// @param swapDataLength Lower bound for the scan — anything before this offset is swapData
    ///                       and cannot contain ExtraData, so the scan stops there.
    /// @return endPoints The right edge (in calldata bytes) of each region, indexed by type.
    ///                   endPoints[0] is the right edge of all ExtraData, located via a 32-byte
    ///                   aligned backward flag scan; it equals calldatasize() when no trailing
    ///                   suffix has been appended.
    /// @return lengths   The number of 32-byte words occupied by each region.
    function _getExtraDataEndPointAndLength(uint256 swapDataLength) private pure returns (
        uint256[] memory endPoints,
        uint256[] memory lengths
    ) {
        endPoints = new uint256[](EXTRA_DATA_TYPE_NUM);
        lengths = new uint256[](EXTRA_DATA_TYPE_NUM);
        assembly ("memory-safe") {
            function _revertWithReason(m, len) {
                mstore(
                    0,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(
                    0x20,
                    0x0000002000000000000000000000000000000000000000000000000000000000
                )
                mstore(0x40, m)
                revert(0, len)
            }

            // Locate the right edge of ExtraData via backward 32-byte aligned flag scan, bounded
            // below by swapDataLength — bytes before that are guaranteed swapData and cannot hold
            // ExtraData, so flag-like patterns accidentally living in ABI params are never read.
            // Initial value strips non-aligned trailing bytes (the external suffix);
            // if no flag is found, parsing degenerates to "no ExtraData" (every length is 0).
            let endPoint := sub(calldatasize(), mod(sub(calldatasize(), 4), 0x20))
            for { let scanPos := endPoint } gt(scanPos, swapDataLength) { scanPos := sub(scanPos, 0x20) } {
                // All four flag masks share the value 0xffffffffffff000…0, so one mask fits all.
                let flagMasked := and(calldataload(sub(scanPos, 0x20)), _COMMISSION_FLAG_MASK)
                if or(
                    or(
                        or(
                            or(eq(flagMasked, FROM_TOKEN_COMMISSION), eq(flagMasked, TO_TOKEN_COMMISSION)),
                            or(eq(flagMasked, FROM_TOKEN_COMMISSION_DUAL), eq(flagMasked, TO_TOKEN_COMMISSION_DUAL))
                        ),
                        or(
                            or(eq(flagMasked, FROM_TOKEN_COMMISSION_MULTIPLE), eq(flagMasked, TO_TOKEN_COMMISSION_MULTIPLE)),
                            or(eq(flagMasked, TRIM_FLAG), eq(flagMasked, TRIM_DUAL_FLAG))
                        )
                    ),
                    or(
                        or(eq(flagMasked, PERMIT2_INFO_SIG65_FLAG), eq(flagMasked, PERMIT2_INFO_SIG64_FLAG)),
                        eq(flagMasked, REFUND_TO_ADDRESS_FLAG)
                    )
                ) {
                    endPoint := scanPos
                    break
                }
            }

            // Get commission data bytes32 endPoint and length (anchor: endPoint)
            let commissionData := calldataload(sub(endPoint, 0x20))
            let flag := and(commissionData, _COMMISSION_FLAG_MASK)
            let referrerNum := 0
            if or(
                eq(flag, FROM_TOKEN_COMMISSION),
                eq(flag, TO_TOKEN_COMMISSION)
            ) {
                referrerNum := 1
            }
            if or(
                eq(flag, FROM_TOKEN_COMMISSION_DUAL),
                eq(flag, TO_TOKEN_COMMISSION_DUAL)
            ) {
                referrerNum := 2
            }
            if or(
                eq(flag, FROM_TOKEN_COMMISSION_MULTIPLE),
                eq(flag, TO_TOKEN_COMMISSION_MULTIPLE)
            ) {
                commissionData := calldataload(sub(endPoint, 0x40))
                referrerNum := shr(240, and(commissionData, _COMMISSION_LENGTH_MASK))
                if or(lt(referrerNum, MIN_COMMISSION_MULTIPLE_NUM), gt(referrerNum, MAX_COMMISSION_MULTIPLE_NUM)) {
                    _revertWithReason(
                        0x0000001520696e76616c6964207265666572726572206e756d00000000000000,
                        0x59
                    ) // "invalid referrer num"
                }
            }
            let length := 0
            if gt(referrerNum, 0) {
                length := add(referrerNum, 1) // bytes32 length for commission is referrerNum + 1 if referrerNum > 0
            }
            mstore(add(endPoints, 0x20), endPoint) // commission data endPoint
            mstore(add(lengths, 0x20), length) // commission data length

            // Get trim data bytes32 endPoint and length
            endPoint := sub(endPoint, mul(length, 0x20)) // refresh endPoint for trim data
            let trimData := calldataload(sub(endPoint, 0x20))
            flag := and(trimData, _TRIM_FLAG_MASK)
            length := 0 // refresh length to 0 for trim data
            if eq(flag, TRIM_FLAG) {
                length := 2
            }
            if eq(flag, TRIM_DUAL_FLAG) {
                length := 3
            }
            mstore(add(endPoints, 0x40), endPoint) // trim data endPoint
            mstore(add(lengths, 0x40), length) // trim data length

            // Get permit2Info data endPoint and length
            endPoint := sub(endPoint, mul(length, 0x20)) // refresh endPoint for permit2Info data
            let permit2InfoData := calldataload(sub(endPoint, 0x20))
            flag := and(permit2InfoData, _PERMIT2_INFO_FLAG_MASK)
            length := 0 // refresh length to 0 for permit2Info data
            if or(
                eq(flag, PERMIT2_INFO_SIG65_FLAG),
                eq(flag, PERMIT2_INFO_SIG64_FLAG)
            ) {
                let amountLength := shr(200, and(permit2InfoData, _PERMIT2_INFO_AMOUNT_LENGTH_MASK))
                length := add(amountLength, 4)
            }
            mstore(add(endPoints, 0x60), endPoint) // permit2Info data endPoint
            mstore(add(lengths, 0x60), length) // permit2Info data length

            // Get refundTo data endPoint and length
            endPoint := sub(endPoint, mul(length, 0x20)) // refresh endPoint for refundTo data
            let refundToData := calldataload(sub(endPoint, 0x20))
            length := 0 // refresh length to 0 for refundTo data
            if eq(and(refundToData, _REFUND_TO_MASK), REFUND_TO_ADDRESS_FLAG) {
                length := 1
            }
            mstore(add(endPoints, 0x80), endPoint) // refundTo data endPoint
            mstore(add(lengths, 0x80), length) // refundTo data length
        }

        return (endPoints, lengths);
    }

    /// @notice Validate extraData boundaries to ensure no overlap with swapData and between regions.
    /// @param endPoints   Array of end points for each extraData region. endPoints[0] is the scan
    ///                    anchor (right edge of all ExtraData) produced by the backward flag scan.
    /// @param lengths     Array of lengths (in 32-byte units) for each extraData region.
    /// @param swapDataLength The length of swapData (4 bytes selector + ABI encoded parameters).
    /// @dev endPoints[0] is guaranteed (4 + 32*K)-aligned because it is either `aligned` (computed
    ///      by stripping non-aligned trailing bytes) or the position of an aligned flag word.
    function _validateExtraDataBoundaries(
        uint256[] memory endPoints,
        uint256[] memory lengths,
        uint256 swapDataLength
    ) private pure {
        // Check 1: Each extraData region must be consecutive (no overlaps or gaps)
        for (uint256 i = 0; i < EXTRA_DATA_TYPE_NUM - 1; ++i) {
            require(endPoints[i + 1] == endPoints[i] - lengths[i] * 32, "ExtraData regions not consecutive");
        }

        // Check 2: Last region's startPoint must be >= swapDataLength (no overlap with swapData)
        require(endPoints[EXTRA_DATA_TYPE_NUM - 1] - lengths[EXTRA_DATA_TYPE_NUM - 1] * 32 >= swapDataLength, "ExtraData overlaps with swapData");
    }

    /// @notice Parse commissionInfo
    function _parseCommissionInfo(uint256 endPoint, uint256 length) private pure returns (IDexRouter.CommissionInfo memory commissionInfo) {
        if (length == 0) {
            return commissionInfo;
        }
        uint256 referrerNum = length - 1; // referrerNum is calculated in getExtraDataEndPointAndLength() function
        assembly ("memory-safe") {
            function _revertWithReason(m, len) {
                mstore(
                    0,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(
                    0x20,
                    0x0000002000000000000000000000000000000000000000000000000000000000
                )
                mstore(0x40, m)
                revert(0, len)
            }

            let commissionData := calldataload(sub(endPoint, 0x20))
            let flag := and(commissionData, _COMMISSION_FLAG_MASK)
            mstore(
                commissionInfo,
                or(
                    or(
                        eq(flag, FROM_TOKEN_COMMISSION),
                        eq(flag, FROM_TOKEN_COMMISSION_DUAL)
                    ),
                    eq(flag, FROM_TOKEN_COMMISSION_MULTIPLE)
                )
            ) // isFromTokenCommission
            mstore(
                add(0x20, commissionInfo),
                or(
                    or(
                        eq(flag, TO_TOKEN_COMMISSION),
                        eq(flag, TO_TOKEN_COMMISSION_DUAL)
                    ),
                    eq(flag, TO_TOKEN_COMMISSION_MULTIPLE)
                )
            ) // isToTokenCommission
            mstore(
                add(0xa0, commissionInfo),
                shr(160, and(commissionData, _COMMISSION_RATE_MASK))
            ) // 1st commissionRate
            mstore(
                add(0xc0, commissionInfo),
                and(commissionData, _ADDRESS_MASK)
            ) // 1st referrerAddress
            commissionData := calldataload(sub(endPoint, 0x40))
            let toBCommission := NO_TO_B_MODE // default toBCommission is 1 for no-toB commission when commissionData exists
            if gt(and(commissionData, _TO_B_COMMISSION_MASK), 0) {
                toBCommission := TO_B_MODE // toB commission value when commissionData exists
            }
            mstore(
                add(0x60, commissionInfo),
                toBCommission //toBCommission
            )
            mstore(
                add(0x40, commissionInfo),
                and(commissionData, _ADDRESS_MASK) //token
            )
            mstore(add(0x80, commissionInfo), referrerNum) //commissionLength

            if gt(referrerNum, 1) {
                for { let i := 1 } lt(i, referrerNum) { i := add(i, 1) } {
                    commissionData := calldataload(sub(endPoint, add(0x40, mul(i, 0x20))))
                    let flag2 := and(commissionData, _COMMISSION_FLAG_MASK)
                    if iszero(eq(flag, flag2)) {
                        _revertWithReason(
                            0x0000001820696e76616c696420636f6d6d697373696f6e20666c616700000000,
                            0x5c
                        ) // "invalid commission flag"
                    }
                    mstore(
                        add(add(0xa0, commissionInfo), mul(i, 0x40)), // 0xa0: commissionRate0, 0xa0 + 0x40 * i: i-th commissionRate
                        shr(160, and(commissionData, _COMMISSION_RATE_MASK))
                    ) //i-th commissionRate
                    mstore(
                        add(add(0xc0, commissionInfo), mul(i, 0x40)), // 0xc0: referrerAddress0, 0xc0 + 0x40 * i: i-th referrerAddress
                        and(commissionData, _ADDRESS_MASK)
                    ) //i-th referrerAddress
                }
            }
        }
        return commissionInfo;
    }

    /// @notice Parse trimInfo
    function _parseTrimInfo(uint256 endPoint, uint256 length) private pure returns (IDexRouter.TrimInfo memory trimInfo) {
        if (length == 0) {
            return trimInfo;
        }
        assembly ("memory-safe") {
            function _revertWithReason(m, len) {
                mstore(
                    0,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(
                    0x20,
                    0x0000002000000000000000000000000000000000000000000000000000000000
                )
                mstore(0x40, m)
                revert(0, len)
            }

            // get first bytes32 of trim data
            let trimData := calldataload(sub(endPoint, 0x20))
            let trimFlag := and(trimData, _TRIM_FLAG_MASK)
            let hasTrim := or(
                eq(trimFlag, TRIM_FLAG),
                eq(trimFlag, TRIM_DUAL_FLAG)
            )
            mstore(
                trimInfo,
                hasTrim
            ) // hasTrim
            switch eq(hasTrim, 1)
            case 1{
                mstore(
                    add(0x20, trimInfo),
                    shr(160, and(trimData, _TRIM_RATE_MASK))
                ) // trimRate
                mstore(
                    add(0x40, trimInfo),
                    and(trimData, _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK)
                ) // trimAddress
                // get second bytes32 of trim data
                trimData := calldataload(sub(endPoint, 0x40))
                let flag := and(trimData, _TRIM_FLAG_MASK)
                if iszero(eq(trimFlag, flag)) {
                    _revertWithReason(
                        0x0000001220696e76616c6964207472696d20666c616700000000000000000000,
                        0x56
                    ) // "invalid trim flag"
                }
                let toBTrim := NO_TO_B_MODE // default toBTrim is 1 for no-toB trim when trimData exists
                if gt(and(trimData, _TO_B_TRIM_MASK), 0) {
                    toBTrim := TO_B_MODE // toB trim value when trimData exists
                }
                mstore(
                    add(0x60, trimInfo),
                    toBTrim //toBTrim
                )
                mstore(
                    add(0x80, trimInfo),
                    and(trimData, _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK)
                ) // expectAmountOut
            }
            default {
                mstore(add(0x20, trimInfo), 0) // trimRate
                mstore(add(0x40, trimInfo), 0) // trimAddress
                mstore(add(0x60, trimInfo), 0) // toBTrim
                mstore(add(0x80, trimInfo), 0) // expectAmountOut
            }
            switch eq(trimFlag, TRIM_DUAL_FLAG)
            case 1 {
                // get third bytes32 of trim data
                trimData := calldataload(sub(endPoint, 0x60))
                let flag := and(trimData, _TRIM_FLAG_MASK)
                if iszero(eq(trimFlag, flag)) {
                    _revertWithReason(
                        0x0000001220696e76616c6964207472696d20666c616700000000000000000000,
                        0x56
                    ) // "invalid trim flag"
                }
                mstore(
                    add(0xa0, trimInfo),
                    shr(160, and(trimData, _TRIM_RATE_MASK))
                ) // chargeRate
                mstore(
                    add(0xc0, trimInfo),
                    and(trimData, _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK)
                ) // chargeAddress
            }
            default {
                mstore(add(0xa0, trimInfo), 0) // chargeRate
                mstore(add(0xc0, trimInfo), 0) // chargeAddress
            }
        }
        return trimInfo;
    }

    /// @notice Parse permit2Info
    function _parsePermit2Info(uint256 endPoint, uint256 length) private view returns (IDexRouter.Permit2Info memory permit2Info) {
        if (length == 0) {
            return permit2Info;
        }
        // Since length == amountLength + 4, so here when length != 0, the length of permit2Info.amounts is length - 4.
        permit2Info.amounts = new uint256[](length - 4);
        uint256 permit2InfoFlag;
        uint256[] memory permit2SignatureCache = new uint256[](3); // signature r, signature s, signature v
        assembly ("memory-safe") {
            function _revertWithReason(m, len) {
                mstore(
                    0,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(
                    0x20,
                    0x0000002000000000000000000000000000000000000000000000000000000000
                )
                mstore(0x40, m)
                revert(0, len)
            }

            // get first bytes32 of permit2Info
            let permit2InfoData := calldataload(sub(endPoint, 0x20))
            permit2InfoFlag := and(permit2InfoData, _PERMIT2_INFO_FLAG_MASK)
            // The first permit2InfoFlag has been verified in getExtraDataEndPointAndLength() function
            let amountLength := sub(length, 4)
            mstore(permit2Info, and(permit2InfoData, _ADDRESS_MASK)) // owner

            // get second bytes32 of permit2Info
            permit2InfoData := calldataload(sub(endPoint, 0x40))
            let flag := and(permit2InfoData, _PERMIT2_INFO_FLAG_MASK)
            if iszero(eq(permit2InfoFlag, flag)) {
                _revertWithReason(
                    0x0000001920696e76616c6964207065726d697432496e666f20666c6167000000,
                    0x5d
                ) // "invalid permit2Info flag"
            }
            mstore(add(permit2Info, 0x20), and(permit2InfoData, _PERMIT2_INFO_NONCE_MASK)) // nonce
            mstore(add(permit2Info, 0x40), shr(48, and(permit2InfoData, _PERMIT2_INFO_DEADLINE_MASK))) // deadline
            if eq(permit2InfoFlag, PERMIT2_INFO_SIG65_FLAG) {
                mstore(add(permit2SignatureCache, 0x60), shr(96, and(permit2InfoData, _PERMIT2_INFO_SIGNATURE_V_MASK))) // signature v
            }
            // get third bytes32 of permit2Info
            permit2InfoData := calldataload(sub(endPoint, 0x60))
            mstore(add(permit2SignatureCache, 0x20), permit2InfoData) // signature r
            // get fourth bytes32 of permit2Info
            permit2InfoData := calldataload(sub(endPoint, 0x80))
            mstore(add(permit2SignatureCache, 0x40), permit2InfoData) // signature s
            // get all amounts
            let amountsPosition := mload(add(permit2Info, 0x80))
            for { let i := 0 } lt(i, amountLength) { i := add(i, 1) } {
                permit2InfoData := calldataload(sub(endPoint, add(0xa0, mul(i, 0x20))))
                mstore(add(amountsPosition, mul(add(i, 1), 0x20)), permit2InfoData) // permit2Info.amounts[i]
            }
        }
        if (permit2InfoFlag == PERMIT2_INFO_SIG65_FLAG) {
            permit2Info.signature = abi.encodePacked(bytes32(permit2SignatureCache[0]), bytes32(permit2SignatureCache[1]), bytes1(uint8(permit2SignatureCache[2])));
        } else if (permit2InfoFlag == PERMIT2_INFO_SIG64_FLAG) {
            permit2Info.signature = abi.encodePacked(bytes32(permit2SignatureCache[0]), bytes32(permit2SignatureCache[1]));
        }

        return permit2Info;
    }

    /// @notice Parse refundTo
    function _parseRefundTo(uint256 endPoint, uint256 length) private pure returns (address refundTo) {
        if (length == 0) {
            return address(0);
        }
        assembly ("memory-safe") {
            let refundToData := calldataload(sub(endPoint, 0x20))
            refundTo := and(refundToData, _ADDRESS_MASK)
        }
        return refundTo;
    }
}