// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Abstract base contract with virtual functions
abstract contract AbstractCommissionLib {
    struct CommissionInfo {
        bool isFromTokenCommission;
        bool isToTokenCommission;
        uint256 commissionRate;
        address refererAddress;
        address token;
        uint256 commissionRate2;
        address refererAddress2;
    }

    function _getCommissionInfo()
        internal
        view
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
