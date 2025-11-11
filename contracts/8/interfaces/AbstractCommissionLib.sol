// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Abstract base contract with virtual functions
abstract contract AbstractCommissionLib {
    struct CommissionInfo {
        bool isFromTokenCommission; //0x00
        bool isToTokenCommission; //0x20
        address token; // 0x40
        uint256 toBCommission; // 0x60, 0 for no commission, 1 for no-toB commission, 2 for toB commission
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

    struct TrimInfo {
        bool hasTrim; // 0x00
        uint256 trimRate; // 0x20
        address trimAddress; // 0x40
        uint256 toBTrim; // 0x60, 0 for no trim, 1 for no-toB trim, 2 for toB trim
        uint256 expectAmountOut; // 0x80
        uint256 chargeRate; // 0xa0
        address chargeAddress; // 0xc0
    }

    function _getCommissionAndTrimInfo()
        internal
        virtual
        returns (CommissionInfo memory commissionInfo, TrimInfo memory trimInfo);

    // function _getBalanceOf(address token, address user)
    //     internal
    //     virtual
    //     returns (uint256);

    function _doCommissionFromToken(
        CommissionInfo memory commissionInfo,
        address payer,
        address receiver,
        uint256 inputAmount,
        bool hasTrim,
        address toToken
    ) internal virtual returns (address, uint256);

    function _doCommissionAndTrimToToken(
        CommissionInfo memory commissionInfo,
        address receiver,
        uint256 balanceBefore,
        address toToken,
        TrimInfo memory trimInfo
    ) internal virtual returns (uint256);

    function _validateCommissionInfo(
        CommissionInfo memory commissionInfo,
        address fromToken,
        address toToken,
        uint256 mode
    ) internal pure virtual;
}
