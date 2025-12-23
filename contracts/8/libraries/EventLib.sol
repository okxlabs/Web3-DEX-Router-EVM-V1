// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title EventLib
/// @notice The single source of truth for all DexRouter event definitions in this repository.
/// @dev This library centralizes DexRouter events to ensure consistency across all contracts and libraries.
///      Other contracts/router should use the emit functions provided here instead of defining events locally.
library EventLib {
    /// ==============================================================
    /// ========================= Events =============================
    /// ==============================================================
    event OrderRecord(
        address fromToken,
        address toToken,
        address sender,
        uint256 fromAmount,
        uint256 returnAmount
    );

    event SwapOrderId(uint256 id);

    event CommissionAndTrimInfo(
        uint256 toBCommission, // 0 for no encoded commission data, 1 for no-toB commission, 2 for toB commission
        uint256 toBTrim, // 0 for no encoded trim data, 1 for no-toB trim, 2 for toB trim
        uint256 trimRate,
        uint256 chargeRate
    );

    // @notice CommissionFromTokenRecord is emitted in assembly, commentted out for contract size saving
    // event CommissionFromTokenRecord(
    //     address fromTokenAddress,
    //     uint256 commissionAmount,
    //     address referrerAddress,
    //     uint256 commissionRate
    // );

    // @notice CommissionToTokenRecord is emitted in assembly, commentted out for contract size saving
    // event CommissionToTokenRecord(
    //     address toTokenAddress,
    //     uint256 commissionAmount,
    //     address referrerAddress,
    //     uint256 commissionRate
    // );

    // @notice PositiveSlippageTrimRecord is emitted in assembly, commentted out for contract size saving
    // event PositiveSlippageTrimRecord(
    //     address toTokenAddress,
    //     uint256 trimAmount,
    //     address trimAddress
    // );

    // @notice PositiveSlippageChargeRecord is emitted in assembly, commentted out for contract size saving
    // event PositiveSlippageChargeRecord(
    //     address toTokenAddress,
    //     uint256 chargeAmount,
    //     address chargeAddress
    // );

    /// ==============================================================
    /// ====================== Emit Functions ========================
    /// ==============================================================
    function emitOrderRecord(
        address fromToken,
        address toToken,
        address sender,
        uint256 fromAmount,
        uint256 returnAmount
    ) internal {
        emit OrderRecord(fromToken, toToken, sender, fromAmount, returnAmount);
    }

    function emitSwapOrderId(uint256 id) internal {
        emit SwapOrderId(id);
    }

    function emitCommissionAndTrimInfo(
        uint256 toBCommission,
        uint256 toBTrim,
        uint256 trimRate,
        uint256 chargeRate
    ) internal {
        emit CommissionAndTrimInfo(toBCommission, toBTrim, trimRate, chargeRate);
    }
}