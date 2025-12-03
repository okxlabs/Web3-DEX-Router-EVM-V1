// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDexRouter.sol";

/// @title Abstract base contract with virtual functions
abstract contract AbstractCommissionLib is IDexRouter {
    function _getExtraData()
        internal
        virtual
        returns (ExtraData memory);

    // function _getBalanceOf(address token, address user)
    //     internal
    //     virtual
    //     returns (uint256);

    function _doCommissionFromToken(
        CommissionInfo memory commissionInfo,
        SwapParams memory swapParams,
        uint256 fromTokenCommissionAmount,
        bool hasTrim
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
