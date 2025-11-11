// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TrimHelper {
    uint256 internal constant TRIM_FLAG =
        0x7777777711110000000000000000000000000000000000000000000000000000;
    uint256 internal constant TRIM_DUAL_FLAG =
        0x7777777722220000000000000000000000000000000000000000000000000000;

    /*
     *  Trim data should be encoded after method calldata and before commission data, the size may be 64 or 96 bytes.
     *  Single Trim:
     *  ┌─────────────┬─────────────┬─────────────────┬─────────────┬─────────────┬─────────────────┐
     *  │ trim_flag   │ padding     │ expect_amount   │ trim_flag   │ trim_rate   │ trim_address    │
     *  │ 6 bytes     │ 6 bytes     │ 20 bytes        │ 6 bytes     │ 6 bytes     │ 20 bytes        │
     *  │0x777777771111│0x000000000000│               │0x777777771111│            │                 │
     *  └─────────────┴─────────────┴─────────────────┴─────────────┴─────────────┴─────────────────┘
     *  ←──────────────--- 32 bytes ---──────────────→ ←──────────────--- 32 bytes ---──────────────→
     *  Dual Trim:
     *  ┌─────────────┬─────────────┬─────────────────┬─────────────┬─────────────┬─────────────────┬─────────────┬─────────────┬─────────────────┐
     *  │ trim_flag   │ charge_rate │ charge_address  │ trim_flag   │ padding     │ expect_amount   │ trim_flag   │ trim_rate   │ trim_address    │
     *  │ 6 bytes     │ 6 bytes     │ 20 bytes        │ 6 bytes     │ 6 bytes     │ 20 bytes        │ 6 bytes     │ 6 bytes     │ 20 bytes        │
     *  │0x777777772222│            │                 │0x777777772222│0x800000000000│               │0x777777772222│            │                 │
     *  └─────────────┴─────────────┴─────────────────┴─────────────┴─────────────┴─────────────────┴─────────────┴─────────────┴─────────────────┘
     *  ←──────────────--- 32 bytes ---──────────────→ ←──────────────--- 32 bytes --──────────────→ ←──────────────--- 32 bytes ---──────────────→
     *  For both single and dual trim, isToBTrim flag is encoded in padding of the second bytes32.
     *  - If isToBTrim is true, the padding is 0x800000000000.
     *  - If isToBTrim is false, the padding is 0x000000000000.
    */

    struct TrimInfo {
        bool hasTrim; // 0x00
        uint256 trimRate; // 0x20
        address trimAddress; // 0x40
        uint256 expectAmountOut; // 0x60
        uint256 chargeRate; // 0x80
        address chargeAddress; // 0xa0
    }

    function _buildTrimInfoUnified(
        uint256 trimRate,
        address trimAddress,
        uint256 expectAmountOut,
        uint256 chargeRate,
        address chargeAddress,
        bool isToBTrim
    ) internal pure returns (bytes memory) {
        // ensure trimRate and chargeRate are valid
        require(trimRate > 0 && trimRate <= 1000);
        require(chargeRate <= 1000);
        // ensure chargeRate and address are valid
        require(
            (chargeRate == 0 && chargeAddress == address(0)) ||
            (chargeRate == 1000 && trimAddress == address(0)) ||
            ((chargeRate > 0 && chargeRate < 1000) && trimAddress != address(0) && chargeAddress != address(0))
        );
        uint256 toBTrimValue = isToBTrim ? (1 << 207) : 0;
        if (chargeRate == 0) {
            return abi.encodePacked(
                bytes32(
                    (TRIM_FLAG & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                    toBTrimValue |
                    (uint256(expectAmountOut) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                ),
                bytes32(
                    (TRIM_FLAG & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                    ((uint256(trimRate) << 160) &    0x000000000000ffffffffffff0000000000000000000000000000000000000000) |
                    (uint256(uint160(trimAddress)) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                )
            );
        } else {
            return abi.encodePacked(
                bytes32(
                    (TRIM_DUAL_FLAG & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                    ((uint256(chargeRate) << 160) & 0x000000000000ffffffffffff0000000000000000000000000000000000000000) |
                    (uint256(uint160(chargeAddress)) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                ),
                bytes32(
                    (TRIM_DUAL_FLAG & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                    toBTrimValue |
                    (uint256(expectAmountOut) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                ),
                bytes32(
                    (TRIM_DUAL_FLAG & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                    ((uint256(trimRate) << 160) & 0x000000000000ffffffffffff0000000000000000000000000000000000000000) |
                    (uint256(uint160(trimAddress)) & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                )
            );
        }
    }

    function _parseTrimInfo(bytes memory trimInfo) internal pure returns (TrimInfo memory) {
        uint256 length = trimInfo.length;
        require(length == 64 || length == 96, "Invalid trim info length");
        TrimInfo memory info;
        bytes32 firstBytes;
        assembly {
            firstBytes := mload(add(trimInfo, length))
        }
        uint256 firstValue = uint256(firstBytes);
        uint256 flag = firstValue & 0xffffffffffff0000000000000000000000000000000000000000000000000000;
        info.hasTrim = ((flag == TRIM_FLAG || flag == TRIM_DUAL_FLAG));
        if (info.hasTrim) {
            info.trimRate = (firstValue >> 160) & 0xffffffffffff;
            info.trimAddress = address(uint160(firstValue & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff));
            bytes32 secondBytes;
            assembly {
                secondBytes := mload(sub(add(trimInfo, length), 32))
            }
            uint256 secondValue = uint256(secondBytes);
            info.expectAmountOut = secondValue & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
        }
        if (flag == TRIM_DUAL_FLAG) {
            bytes32 thirdBytes;
            assembly {
                thirdBytes := mload(sub(add(trimInfo, length), 64))
            }
            uint256 thirdValue = uint256(thirdBytes);
            info.chargeRate = (thirdValue >> 160) & 0xffffffffffff;
            info.chargeAddress = address(uint160(thirdValue & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff));
        }
        return info;
    }
}