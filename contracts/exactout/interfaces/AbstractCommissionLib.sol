// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Abstract base contract with virtual functions
abstract contract AbstractCommissionLib {
    struct CommissionInfo {
        bool isFromTokenCommission; //0x00
        bool isToTokenCommission; //0x20
        uint256 commissionRate; //0x40
        address refererAddress; //0x60
        address token; //0x80
        uint256 commissionRate2; //0xa0
        address refererAddress2; //0xc0
        bool isToBCommission; //0xe0
    }

    function _getCommissionInfo()
        internal
        pure
        virtual
        returns (CommissionInfo memory commissionInfo);

    // function _getBalanceOf(address token, address user)
    //     internal
    //     virtual
    //     returns (uint256);

    function _doCommissionFromToken(
        CommissionInfo memory commissionInfo,
        address srcToken,
        address payer,
        address receiver,
        uint256 inputAmount
    ) internal virtual returns (address, uint256);

    function _doCommissionToToken(
        CommissionInfo memory commissionInfo,
        address receiver,
        uint256 balanceBefore
    ) internal virtual returns (uint256);
}
