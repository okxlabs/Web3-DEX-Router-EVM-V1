// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";

contract CommissionHelper {
    uint256 internal constant FROM_TOKEN_COMMISSION =
        0x3ca20afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TO_TOKEN_COMMISSION =
        0x3ca20afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 internal constant FROM_TOKEN_COMMISSION_DUAL =
        0x22220afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TO_TOKEN_COMMISSION_DUAL =
        0x22220afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 internal constant FROM_TOKEN_COMMISSION_MULTIPLE =
        0x88880afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TO_TOKEN_COMMISSION_MULTIPLE =
        0x88880afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 internal constant _COMMISSION_RATE_MASK =
        0x000000000000ffffffffffff0000000000000000000000000000000000000000;
    uint256 internal constant _COMMISSION_FLAG_MASK =
        0xffffffffffff0000000000000000000000000000000000000000000000000000;
    uint256 internal constant _COMMISSION_LENGTH_MASK =
        0x00ff000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant _TO_B_COMMISSION_MASK =
        0x8000000000000000000000000000000000000000000000000000000000000000;
    uint256 internal constant _ADDRESS_MASK =
        0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    uint256 internal constant MIN_COMMISSION_MULTIPLE_NUM = 3; // min referrer num for multiple commission
    uint256 internal constant MAX_COMMISSION_MULTIPLE_NUM = 8; // max referrer num for multiple commission

    /*
     * Single commission:
     * ┌──────────────────────────────────────────┬──────────────────────────────────────────┐
     * │            2nd bytes32                   │              1st bytes32                 │
     * │      (isToB + padding + token_addr)      │      (flag + rate + referer_addr)        │
     * ├────────┬──────────────────┬──────────────┼─────────────┬─────────────┬──────────────┤
     * │ isToB  │     padding      │token_address │    flag     │    rate     │referer_addr  │
     * │ 1 byte │    11 bytes      │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │
     * ├────────┼──────────────────┼──────────────┼─────────────┼─────────────┼──────────────┤
     * │ 0x80or │0x0000000000000000000000│ token  │0x3ca20afc   │    rate1    │  referrer1   │
     * │ 0x00   │                  │              │2aaa/2bbb    │             │              │
     * └────────┴──────────────────┴──────────────┴─────────────┴─────────────┴──────────────┘
     * Dual commission:
     * ┌──────────────────────────────────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┐
     * │            3rd bytes32                   │            2nd bytes32                   │             1st bytes32                  │
     * │      (flag + rate2 + referer_addr2)      │      (isToB + padding + token_addr)      │      (flag + rate1 + referer_addr1)      │
     * ├─────────────┬─────────────┬──────────────┼────────┬──────────────────┬──────────────┼─────────────┬─────────────┬──────────────┤
     * │    flag     │   rate2     │referer_addr2 │ isToB  │     padding      │token_address │    flag     │   rate1     │referer_addr1 │
     * │   6 bytes   │   6 bytes   │   20 bytes   │ 1 byte │    11 bytes      │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │
     * ├─────────────┼─────────────┼──────────────┼────────┼──────────────────┼──────────────┼─────────────┼─────────────┼──────────────┤
     * │0x22220afc   │   rate2     │   referer2   │ 0x80or │0x0000000000000000000000│ token  │0x22220afc   │   rate1     │   referer1   │
     * │2aaa/2bbb    │             │              │ 0x00   │                  │              │2aaa/2bbb    │             │              │
     * └─────────────┴─────────────┴──────────────┴────────┴──────────────────┴──────────────┴─────────────┴─────────────┴──────────────┘
     * Multiple commission:
     * ┌────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┬──────────────────────────────────────────┐
     * │            │            4th bytes32                   │            3rd bytes32                   │            2nd bytes32                   │             1st bytes32                  │
     * │            │      (flag + rate3 + referer_addr3)      │      (flag + rate2 + referer_addr2)      │      (isToB + padding + token_addr)      │      (flag + rate1 + referer_addr1)      │
     * │ Maybe      ├─────────────┬─────────────┬──────────────┼─────────────┬─────────────┬──────────────┼────────┬───────┬──────────┬──────────────┼─────────────┬─────────────┬──────────────┤
     * │ more       │    flag     │   rate3     │referer_addr3 │    flag     │   rate2     │referer_addr2 │ isToB  │padding|referrer_num│token_address│    flag    │   rate1     │referer_addr1 │
     * │ commission │   6 bytes   │   6 bytes   │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │ 1 byte │10bytes|  1 byte  │   20 bytes   │   6 bytes   │   6 bytes   │   20 bytes   │
     * │            ├─────────────┼─────────────┼──────────────┼─────────────┼─────────────┼──────────────┼────────┼───────┼──────────┼──────────────┼─────────────┼─────────────┼──────────────┤
     * │            │0x88880afc   │   rate3     │   referer3   │0x88880afc   │   rate2     │   referer2   │ 0x80or |10 empty| num >=3 |    token     │0x88880afc   │   rate1     │   referer1   │
     * │            │2aaa/2bbb    │             │              │2aaa/2bbb    │             │              │ 0x00   │ bytes |&& num <=8│              │2aaa/2bbb    │             │              │
     * └────────────┴─────────────┴─────────────┴──────────────┴─────────────┴─────────────┴──────────────┴────────┴──────────────────┴──────────────┴─────────────┴─────────────┴──────────────┘
    */

    // Parse commission info from encoded bytes
    // Returns a struct containing all parsed commission parameters
    struct CommissionInfo {
        bool isFromTokenCommission; //0x00
        bool isToTokenCommission; //0x20
        address token; // 0x40
        bool isToBCommission; // 0x60
        uint256 commissionLength; // 0x80
        uint256 commissionRate; // 0xa0
        address referrerAddress; // 0xc0
        uint256 commissionRate2; // 0xe0
        address referrerAddress2; // 0x100
        uint256 commissionRate3; // 0x120
        address referrerAddress3; // 0x140
        uint256 commissionRate4; // 0x160
        address referrerAddress4; // 0x180
        uint256 commissionRate5; // 0x1a0
        address referrerAddress5; // 0x1c0
        uint256 commissionRate6; // 0x1e0
        address referrerAddress6; // 0x200
        uint256 commissionRate7; // 0x220
        address referrerAddress7; // 0x240
        uint256 commissionRate8; // 0x260
        address referrerAddress8; // 0x280
    }

    // Unified commission info builder for commission
    // isFromTokenCommission and isToTokenCommission cannot both be true or both be false
    // Elements at the same index in commissionRates and referrerAddresses must both have values or both be 0
    function _buildCommissionInfoUnified(
        bool isFromTokenCommission,
        bool isToTokenCommission,
        address token,
        bool isToBCommission,
        uint256[] memory commissionRates,
        address[] memory referrerAddresses
    ) internal pure returns (bytes memory) {
        // Verify that isFromTokenCommission and isToTokenCommission cannot both be true or both be false
        require(
            isFromTokenCommission != isToTokenCommission,
            "Exactly one of isFromTokenCommission or isToTokenCommission must be true"
        );
        // Verify that elements at the same index in commissionRates and referrerAddresses must both have values or both be 0, and validate length
        uint256 commissionLength = commissionRates.length;
        require(commissionLength == referrerAddresses.length, "commissionRates and referrerAddresses must have the same length");
        require(commissionLength >= 1 && commissionLength <= MAX_COMMISSION_MULTIPLE_NUM, "invalid commission length");
        for (uint256 i = 0; i < commissionLength; i++) {
            require(commissionRates[i] == 0 && referrerAddresses[i] == address(0) || commissionRates[i] > 0 && referrerAddresses[i] != address(0), "commissionRates and referrerAddresses value must be set or unset at the same index");
        }
        bytes memory commissionInfo;
        uint256 toBCommissionFlag = isToBCommission ? (1 << 255) : 0;
        uint256 flagValue;
        uint256 lengthValue = 0;
        if (commissionLength == 1) {
            if (isFromTokenCommission) {
                flagValue = FROM_TOKEN_COMMISSION;
            } else {
                flagValue = TO_TOKEN_COMMISSION;
            }
        } else if (commissionLength == 2) {
            if (isFromTokenCommission) {
                flagValue = FROM_TOKEN_COMMISSION_DUAL;
            } else {
                flagValue = TO_TOKEN_COMMISSION_DUAL;
            }
        } else {
            if (isFromTokenCommission) {
                flagValue = FROM_TOKEN_COMMISSION_MULTIPLE;
            } else {
                flagValue = TO_TOKEN_COMMISSION_MULTIPLE;
            }
            lengthValue = commissionLength << 240; // length is only encoded when commissionLength > 2
        }

        // At least one referrer address, assemble the first 2 bytes32
        commissionInfo = abi.encodePacked(
            bytes32(toBCommissionFlag | lengthValue | uint256(uint160(token))),
            bytes32(
                (flagValue & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                ((uint256(commissionRates[0]) << 160) & 0x000000000000ffffffffffff0000000000000000000000000000000000000000) |
                (uint256(uint160(referrerAddresses[0])) & 0x00000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
            )
        );
        // Assemble the remaining bytes32
        for (uint256 i = 1; i < commissionLength; i++) {
            commissionInfo = abi.encodePacked(
                bytes32(
                    (flagValue & 0xffffffffffff0000000000000000000000000000000000000000000000000000) |
                    ((uint256(commissionRates[i]) << 160) & 0x000000000000ffffffffffff0000000000000000000000000000000000000000) |
                    (uint256(uint160(referrerAddresses[i])) & 0x00000000000000000000000000ffffffffffffffffffffffffffffffffffffffff)
                ),
                commissionInfo
            );
        }
        return commissionInfo;
    }

    function _parseCommissionInfo(bytes memory encodedCommissionInfo) internal view returns (CommissionInfo memory commissionInfo) {
        uint256 bytesLength = encodedCommissionInfo.length;
        require(bytesLength >= 64, "Invalid commission info length");
        
        CommissionInfo memory info;

        // Same parse logic as _getCommissionAndTrimInfo in CommissionLib.sol except the commissionData loading logic
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

            let commissionData := mload(add(encodedCommissionInfo, bytesLength)) // directly load the last bytes32 of encodedCommissionInfo
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
                referrerNum := 3 // default referrer num to load real encoded referrer num
            }
            mstore(
                commissionInfo,
                or(
                    eq(flag, FROM_TOKEN_COMMISSION),
                    eq(flag, FROM_TOKEN_COMMISSION_DUAL)
                )
            ) // isFromTokenCommission
            mstore(
                add(0x20, commissionInfo),
                or(
                    eq(flag, TO_TOKEN_COMMISSION),
                    eq(flag, TO_TOKEN_COMMISSION_DUAL)
                )
            ) // isToTokenCommission
            switch gt(referrerNum, 0)
            case 1 {
                mstore(
                    add(0xa0, commissionInfo),
                    shr(160, and(commissionData, _COMMISSION_RATE_MASK))
                ) // 1st commissionRate
                mstore(
                    add(0xc0, commissionInfo),
                    and(commissionData, _ADDRESS_MASK)
                ) // 1st referrerAddress
                commissionData := mload(sub(add(encodedCommissionInfo, bytesLength), 0x20)) // load the second last bytes32 of encodedCommissionInfo
                mstore(
                    add(0x60, commissionInfo),
                    gt(and(commissionData, _TO_B_COMMISSION_MASK), 0) //isToBCommission
                )
                mstore(
                    add(0x40, commissionInfo),
                    and(commissionData, _ADDRESS_MASK) //token
                )
                // For multiple commission mode, load the encoded commission length and validate
                if gt(referrerNum, 2) {
                    referrerNum := shr(240, and(commissionData, _COMMISSION_LENGTH_MASK))
                    // require(referrerNum >= MIN_COMMISSION_MULTIPLE_NUM && referrerNum <= MAX_COMMISSION_MULTIPLE_NUM, "invalid referrer num")
                    if or(lt(referrerNum, MIN_COMMISSION_MULTIPLE_NUM), gt(referrerNum, MAX_COMMISSION_MULTIPLE_NUM)) {
                        _revertWithReason(
                            0x00000014696e76616c6964207265666572726572206e756d0000000000000000,
                            0x58
                        ) // "invalid referrer num"
                    }
                }
                mstore(add(0x80, commissionInfo), referrerNum) //commissionLength
            }
            default {
                let eraseNum := add(mul(MAX_COMMISSION_MULTIPLE_NUM, 2), 3) // 2 * MAX_COMMISSION_MULTIPLE_NUM + 3: token, isToBCommission, commissionLength and all commission pairs
                for { let i := 0 } lt(i, eraseNum) { i := add(i, 1) } {
                    mstore(add(add(commissionInfo, 0x40), mul(i, 0x20)), 0) // erase commissionInfo.token ~ all commission pairs
                }
            }
            if gt(referrerNum, 1) {
                for { let i := 1 } lt(i, MAX_COMMISSION_MULTIPLE_NUM) { i := add(i, 1) } {
                    switch lt(i, referrerNum) // if i < referrerNum, the i-th commission pair is valid
                    case 1 {
                        commissionData := mload(sub(add(encodedCommissionInfo, bytesLength), add(0x20, mul(i, 0x20)))) // load the i-th last bytes32 of encodedCommissionInfo
                        let flag2 := and(commissionData, _COMMISSION_FLAG_MASK)
                        if iszero(eq(flag, flag2)) {
                            _revertWithReason(
                                0x00000017696e76616c696420636f6d6d697373696f6e20666c61670000000000,
                                0x5b
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
                    default { // if i >= referrerNum, the i-th commission pair is invalid, and erase it
                        mstore(add(add(0xa0, commissionInfo), mul(i, 0x40)), 0) // erase i-th commissionRate
                        mstore(add(add(0xc0, commissionInfo), mul(i, 0x40)), 0) // erase i-th referrerAddress
                    }
                }
            }
        }
    }

    // function test_commissionInfo_buildAndParse() public {
    //     uint256[] memory commissionRates = new uint256[](4);
    //     commissionRates[0] = 1000000;
    //     commissionRates[1] = 2000000;
    //     commissionRates[2] = 3000000;
    //     commissionRates[3] = 4000000;
    //     address[] memory referrerAddresses = new address[](4);
    //     referrerAddresses[0] = address(0x1234567890123456789012345678900000000000);
    //     referrerAddresses[1] = address(0x1234567890123456789012345678911111111111);
    //     referrerAddresses[2] = address(0x1234567890123456789012345678922222222222);
    //     referrerAddresses[3] = address(0x1234567890123456789012345678933333333333);
    //     bytes memory commissionInfo = _buildCommissionInfoUnified(true, false, address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), true, commissionRates, referrerAddresses);
       
    //     console2.log("commissionInfo:");
    //     console2.logBytes(commissionInfo);

    //     CommissionInfo memory info = _parseCommissionInfo(commissionInfo);

    //     console2.log("commissionInfo.isFromTokenCommission:", info.isFromTokenCommission);
    //     console2.log("commissionInfo.isToTokenCommission:", info.isToTokenCommission);
    //     console2.log("commissionInfo.token:", info.token);
    //     console2.log("commissionInfo.isToBCommission:", info.isToBCommission);
    //     console2.log("commissionInfo.commissionLength:", info.commissionLength);
    //     console2.log("commissionInfo.commissionRate:", info.commissionRate);
    //     console2.log("commissionInfo.referrerAddress:", info.referrerAddress);
    //     console2.log("commissionInfo.commissionRate2:", info.commissionRate2);
    //     console2.log("commissionInfo.referrerAddress2:", info.referrerAddress2);
    //     console2.log("commissionInfo.commissionRate3:", info.commissionRate3);
    //     console2.log("commissionInfo.referrerAddress3:", info.referrerAddress3);
    //     console2.log("commissionInfo.commissionRate4:", info.commissionRate4);
    //     console2.log("commissionInfo.referrerAddress4:", info.referrerAddress4);
    // }
}