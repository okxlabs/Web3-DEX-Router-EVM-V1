/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CommonUtils.sol";
import "../interfaces/AbstractCommissionLib.sol";
/// @title Base contract with common permit handling logics

abstract contract CommissionLib is AbstractCommissionLib, CommonUtils {
    uint256 internal constant _COMMISSION_RATE_MASK =
        0x000000000000ffffffffffff0000000000000000000000000000000000000000;
    uint256 internal constant _COMMISSION_FLAG_MASK =
        0xffffffffffff0000000000000000000000000000000000000000000000000000;
    uint256 internal constant FROM_TOKEN_COMMISSION =
        0x3ca20afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TO_TOKEN_COMMISSION =
        0x3ca20afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 internal constant FROM_TOKEN_COMMISSION_DUAL =
        0x22220afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TO_TOKEN_COMMISSION_DUAL =
        0x22220afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 internal constant FROM_TOKEN_COMMISSION_TRIPLE =
        0x33330afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 internal constant TO_TOKEN_COMMISSION_TRIPLE =
        0x33330afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 internal constant _TO_B_COMMISSION_MASK =
        0x8000000000000000000000000000000000000000000000000000000000000000;

    uint256 internal constant _TRIM_FLAG_MASK =
        0xffffffffffff0000000000000000000000000000000000000000000000000000;
    uint256 internal constant _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK =
        0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 internal constant _TRIM_RATE_MASK =
        0x000000000000ffffffffffff0000000000000000000000000000000000000000;
    uint256 internal constant TRIM_FLAG =
        0x7777777711110000000000000000000000000000000000000000000000000000;
    uint256 internal constant TRIM_DUAL_FLAG =
        0x7777777722220000000000000000000000000000000000000000000000000000;

    event CommissionAndTrimInfo(
        uint256 commissionRate1,
        uint256 commissionRate2,
        uint256 commissionRate3,
        bool isToBCommission,
        uint256 trimRate,
        uint256 chargeRate
    );

    // @notice CommissionFromTokenRecord is emitted in assembly, commentted out for contract size saving
    // event CommissionFromTokenRecord(
    //     address fromTokenAddress,
    //     uint256 commissionAmount,
    //     address referrerAddress
    // );

    // @notice CommissionToTokenRecord is emitted in assembly, commentted out for contract size saving
    // event CommissionToTokenRecord(
    //     address toTokenAddress,
    //     uint256 commissionAmount,
    //     address referrerAddress
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

    // set default value can change when need.
    uint256 internal constant commissionRateLimit = 30000000;
    uint256 internal constant DENOMINATOR = 10 ** 9;
    uint256 internal constant WAD = 1 ether;
    uint256 internal constant TRIM_RATE_LIMIT = 100;
    uint256 internal constant TRIM_DENOMINATOR = 1000;

    function _getCommissionAndTrimInfo()
        internal
        override
        returns (CommissionInfo memory commissionInfo, TrimInfo memory trimInfo)
    {
        assembly ("memory-safe") {
            let commissionData := calldataload(sub(calldatasize(), 0x20))
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
                eq(flag, FROM_TOKEN_COMMISSION_TRIPLE),
                eq(flag, TO_TOKEN_COMMISSION_TRIPLE)
            ) {
                referrerNum := 3
            }
            mstore(
                commissionInfo,
                or(
                    or(
                        eq(flag, FROM_TOKEN_COMMISSION),
                        eq(flag, FROM_TOKEN_COMMISSION_DUAL)
                    ),
                    eq(flag, FROM_TOKEN_COMMISSION_TRIPLE)
                )
            ) // isFromTokenCommission
            mstore(
                add(0x20, commissionInfo),
                or(
                    or(
                        eq(flag, TO_TOKEN_COMMISSION),
                        eq(flag, TO_TOKEN_COMMISSION_DUAL)
                    ),
                    eq(flag, TO_TOKEN_COMMISSION_TRIPLE)
                )
            ) // isToTokenCommission
            switch gt(referrerNum, 0)
            case 1 {
                mstore(
                    add(0x40, commissionInfo),
                    shr(160, and(commissionData, _COMMISSION_RATE_MASK))
                ) //commissionRate1
                mstore(
                    add(0x60, commissionInfo),
                    and(commissionData, _ADDRESS_MASK)
                ) //referrerAddress1
                commissionData := calldataload(sub(calldatasize(), 0x40))
                mstore(
                    add(0xe0, commissionInfo),
                    gt(and(commissionData, _TO_B_COMMISSION_MASK), 0) //isToBCommission
                )
                mstore(
                    add(0x80, commissionInfo),
                    and(commissionData, _ADDRESS_MASK) //token
                )
            }
            default {
                mstore(add(0x40, commissionInfo), 0) //commissionRate1
                mstore(add(0x60, commissionInfo), 0) //referrerAddress1
                mstore(add(0xe0, commissionInfo), 0) //isToBCommission
                mstore(add(0x80, commissionInfo), 0) //token
            }
            switch gt(referrerNum, 1)
            case 1 {
                let commissionData2 := calldataload(sub(calldatasize(), 0x60))
                mstore(
                    add(0xa0, commissionInfo),
                    shr(160, and(commissionData2, _COMMISSION_RATE_MASK))
                ) //commissionRate2
                mstore(
                    add(0xc0, commissionInfo),
                    and(commissionData2, _ADDRESS_MASK)
                ) //referrerAddress2
            }
            default {
                mstore(add(0xa0, commissionInfo), 0) //commissionRate2
                mstore(add(0xc0, commissionInfo), 0) //referrerAddress2
            }
            switch gt(referrerNum, 2)
            case 1 {
                let commissionData3 := calldataload(sub(calldatasize(), 0x80))
                mstore(
                    add(0x100, commissionInfo),
                    shr(160, and(commissionData3, _COMMISSION_RATE_MASK))
                ) //commissionRate3
                mstore(
                    add(0x120, commissionInfo),
                    and(commissionData3, _ADDRESS_MASK)
                ) //referrerAddress3
            }
            default {
                mstore(add(0x100, commissionInfo), 0) //commissionRate3
                mstore(add(0x120, commissionInfo), 0) //referrerAddress3
            }
            // calculate offset based on referrerNum
            let offset := 0
            if gt(referrerNum, 0) {
                offset := mul(add(referrerNum, 1), 32)
            }
            // get first bytes32 of trim data
            let trimData := calldataload(sub(calldatasize(), add(offset, 32)))
            flag := and(trimData, _TRIM_FLAG_MASK)
            let hasTrim := or(
                eq(flag, TRIM_FLAG),
                eq(flag, TRIM_DUAL_FLAG)
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
                trimData := calldataload(sub(calldatasize(), add(offset, 64)))
                mstore(
                    add(0x60, trimInfo),
                    and(trimData, _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK)
                ) // expectAmountOut
            }
            default {
                mstore(add(0x20, trimInfo), 0) // trimRate
                mstore(add(0x40, trimInfo), 0) // trimAddress
                mstore(add(0x60, trimInfo), 0) // expectAmountOut
            }
            switch eq(flag, TRIM_DUAL_FLAG)
            case 1 {
                // get third bytes32 of trim data
                trimData := calldataload(sub(calldatasize(), add(offset, 96)))
                mstore(
                    add(0x80, trimInfo),
                    shr(160, and(trimData, _TRIM_RATE_MASK))
                ) // chargeRate
                mstore(
                    add(0xa0, trimInfo),
                    and(trimData, _TRIM_EXPECT_AMOUNT_OUT_OR_ADDRESS_MASK)
                ) // chargeAddress
            }
            default {
                mstore(add(0x80, trimInfo), 0) // chargeRate
                mstore(add(0xa0, trimInfo), 0) // chargeAddress
            }
        }

        if (commissionInfo.isFromTokenCommission || commissionInfo.isToTokenCommission || trimInfo.hasTrim) {
            emit CommissionAndTrimInfo(commissionInfo.commissionRate, commissionInfo.commissionRate2, commissionInfo.commissionRate3, commissionInfo.isToBCommission, trimInfo.trimRate, trimInfo.chargeRate);
        }
    }

    function _getBalanceOf(
        address token,
        address user
    ) internal returns (uint256 amount) {
        assembly {
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
            switch eq(token, _ETH)
            case 1 {
                amount := balance(user)
            }
            default {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x24))
                mstore(
                    freePtr,
                    0x70a0823100000000000000000000000000000000000000000000000000000000
                ) //balanceOf
                mstore(add(freePtr, 0x04), user)
                let success := staticcall(gas(), token, freePtr, 0x24, 0, 0x20)
                if eq(success, 0) {
                    _revertWithReason(
                        0x000000146765742062616c616e63654f66206661696c65640000000000000000,
                        0x58
                    )
                }
                amount := mload(0x00)
            }
        }
    }

    function _doCommissionFromToken(
        CommissionInfo memory commissionInfo,
        address payer,
        address receiver,
        uint256 inputAmount,
        bool hasTrim,
        address toToken
    ) internal override returns (address middleReceiver, uint256 balanceBefore) {
        if (commissionInfo.isToTokenCommission || hasTrim) {
            middleReceiver = address(this);
            balanceBefore = _getBalanceOf(toToken, address(this));
        } else {
            middleReceiver = receiver;
        }

        if (commissionInfo.isFromTokenCommission) {
            _doCommissionFromTokenInternal(commissionInfo, payer, inputAmount);
        }
    }

    function _doCommissionFromTokenInternal(
        CommissionInfo memory commissionInfo,
        address payer,
        uint256 inputAmount
    ) private {
        assembly ("memory-safe") {
            // https://github.com/Vectorized/solady/blob/701406e8126cfed931645727b274df303fbcd94d/src/utils/FixedPointMathLib.sol#L595
            function _mulDiv(x, y, d) -> z {
                z := mul(x, y)
                // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
                if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                    mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                    revert(0x1c, 0x04)
                }
                z := div(z, d)
            }
            function _safeSub(x, y) -> z {
                if lt(x, y) {
                    mstore(0x00, 0x46e72d03) // `SafeSubFailed()`.
                    revert(0x1c, 0x04)
                }
                z := sub(x, y)
            }
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
            function _sendETH(to, amount) {
                let success := call(gas(), to, amount, 0, 0, 0, 0)
                if eq(success, 0) {
                    _revertWithReason(
                        0x0000001c20636f6d6d697373696f6e2077697468206574686572206572726f72, //commission with ether error
                        0x60
                    )
                }
            }
            function _claimToken(token, _payer, to, amount) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x84))
                mstore(
                    freePtr,
                    0x0a5ea46600000000000000000000000000000000000000000000000000000000
                ) // claimTokens
                mstore(add(freePtr, 0x04), token)
                mstore(add(freePtr, 0x24), _payer)
                mstore(add(freePtr, 0x44), to)
                mstore(add(freePtr, 0x64), amount)
                let success := call(
                    gas(),
                    _APPROVE_PROXY,
                    0,
                    freePtr,
                    0x84,
                    0,
                    0
                )
                if eq(success, 0) {
                    _revertWithReason(
                        0x00000013636c61696d20746f6b656e73206661696c6564000000000000000000,
                        0x57
                    )
                }
            }
            function _sendToken(token, to, amount) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x44))
                mstore(
                    freePtr,
                    0xa9059cbb00000000000000000000000000000000000000000000000000000000
                ) // transfer
                mstore(add(freePtr, 0x04), to)
                mstore(add(freePtr, 0x24), amount)
                let success := call(
                    gas(),
                    token,
                    0,
                    freePtr,
                    0x44,
                    0,
                    0x20
                )
                if and(
                    iszero(and(eq(mload(0), 1), gt(returndatasize(), 31))),
                    success
                ) {
                    success := iszero(
                        or(iszero(extcodesize(token)), returndatasize())
                    )
                }
                if eq(success, 0) {
                    _revertWithReason(
                        0x0000001b7472616e7366657220746f6b656e2072656665726572206661696c00,
                        0x5f
                    ) //transfer token referrer fail
                }
            }
            // get balance, then scale amount1, amount2 and amount3 according to balance, and send tokens with scaled amount
            function _sendTokenWithinBalanceAndEmitEvents(token, to1, rate1, to2, rate2, to3, rate3)
            {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x48))
                mstore(
                    freePtr,
                    0x70a0823100000000000000000000000000000000000000000000000000000000
                ) // balanceOf
                // get token balance of address(this)
                mstore(add(freePtr, 0x4), address())
                let success := staticcall(
                    gas(),
                    token,
                    freePtr,
                    0x24,
                    0,
                    0x20
                )
                if eq(success, 0) {
                    _revertWithReason(
                        0x000000146765742062616c616e63654f66206661696c65640000000000000000,
                        0x58
                    )
                }
                let balanceAfter := mload(0x00)
                let rateTotal := add(add(rate1, rate2), rate3) // amount = 0.0000001
                let amount1Scaled, amount2Scaled, amount3Scaled
                // send token to referrer1
                if gt(rate1, 0) {
                    amount1Scaled := _mulDiv(
                        _mulDiv(rate1, WAD, rateTotal),
                        balanceAfter,
                        WAD
                    ) // WARNING: Precision issues may also exist!!
                    if gt(amount1Scaled, balanceAfter) {
                        _revertWithReason(
                            0x00000015696e76616c696420616d6f756e74315363616c656400000000000000,
                            0x59
                        ) //invalid amount1Scaled
                    }
                    _sendToken(token, to1, amount1Scaled)
                    _emitCommissionFromToken(token, amount1Scaled, to1)
                }
                // send token to referrer2
                if gt(rate2, 0) {
                    amount2Scaled := _mulDiv(
                        _mulDiv(rate2, WAD, rateTotal),
                        balanceAfter,
                        WAD
                    ) // WARNING: Precision issues may also exist!!
                    if gt(amount2Scaled, balanceAfter) {
                        _revertWithReason(
                            0x00000015696e76616c696420616d6f756e74325363616c656400000000000000,
                            0x59
                        ) //invalid amount2Scaled
                    }
                    _sendToken(token, to2, amount2Scaled)
                    _emitCommissionFromToken(token, amount2Scaled, to2)
                }
                // send token to referrer3
                if gt(rate3, 0) {
                    amount3Scaled := _safeSub(balanceAfter, add(amount1Scaled, amount2Scaled))
                    _sendToken(token, to3, amount3Scaled)
                    _emitCommissionFromToken(token, amount3Scaled, to3)
                }
            }
            function _emitCommissionFromToken(token, amount, referrer) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x60))
                mstore(freePtr, token)
                mstore(add(freePtr, 0x20), amount)
                mstore(add(freePtr, 0x40), referrer)
                log1(
                    freePtr,
                    0x60,
                    0x0d3b1268ca3dbb6d3d8a0ea35f44f8f9d58cf578d732680b71b6904fb2733e0d
                ) //emit CommissionFromTokenRecord(address,uint256,address)
            }

            let token := mload(add(commissionInfo, 0x80))
            let isToB := mload(add(commissionInfo, 0xe0))            
            let referrer1, referrer2, referrer3, rate1, rate2, rate3, totalRate
            {
                rate1 := mload(add(commissionInfo, 0x40))
                rate2 := mload(add(commissionInfo, 0xa0))
                rate3 := mload(add(commissionInfo, 0x100))
                totalRate := add(add(rate1, rate2), rate3)
                if gt(totalRate, commissionRateLimit) {
                    _revertWithReason(
                        0x0000001b6572726f7220636f6d6d697373696f6e2072617465206c696d697400,
                        0x5f
                    ) //"error commission rate limit"
                }
                referrer1 := mload(add(commissionInfo, 0x60))
                referrer2 := mload(add(commissionInfo, 0xc0))
                referrer3 := mload(add(commissionInfo, 0x120))
            }

            if eq(token, _ETH) { // commission token is ETH, the process is same between no toB mode and toB mode
                if gt(rate1, 0) {
                    let amount1 := div(
                        mul(inputAmount, rate1),
                        sub(DENOMINATOR, totalRate)
                    )
                    _sendETH(referrer1, amount1)
                    _emitCommissionFromToken(_ETH, amount1, referrer1)
                }
                if gt(rate2, 0) {
                    let amount2 := div(
                        mul(inputAmount, rate2),
                        sub(DENOMINATOR, totalRate)
                    )
                    _sendETH(referrer2, amount2)
                    _emitCommissionFromToken(_ETH, amount2, referrer2)
                }
                if gt(rate3, 0) {
                    let amount3 := div(
                        mul(inputAmount, rate3),
                        sub(DENOMINATOR, totalRate)
                    )
                    _sendETH(referrer3, amount3)
                    _emitCommissionFromToken(_ETH, amount3, referrer3)
                }
            }
            if and(iszero(eq(token, _ETH)), iszero(isToB)) { // commission token is ERC20 with no toB mode
                if gt(rate1, 0) {
                    let amount1 := div(
                        mul(inputAmount, rate1),
                        sub(DENOMINATOR, totalRate)
                    )
                    _claimToken(token, payer, referrer1, amount1)
                    _emitCommissionFromToken(token, amount1, referrer1)
                }
                if gt(rate2, 0) {
                    let amount2 := div(
                        mul(inputAmount, rate2),
                        sub(DENOMINATOR, totalRate)
                    )
                    _claimToken(token, payer, referrer2, amount2)
                    _emitCommissionFromToken(token, amount2, referrer2)
                }
                if gt(rate3, 0) {
                    let amount3 := div(
                        mul(inputAmount, rate3),
                        sub(DENOMINATOR, totalRate)
                    )
                    _claimToken(token, payer, referrer3, amount3)
                    _emitCommissionFromToken(token, amount3, referrer3)
                }
            }
            if and(iszero(eq(token, _ETH)), isToB) { // commission token is ERC20 with toB mode
                let totalAmount := div(
                    mul(inputAmount, totalRate),
                    sub(DENOMINATOR, totalRate)
                )
                _claimToken(token, payer, address(), totalAmount)
                _sendTokenWithinBalanceAndEmitEvents(
                    token,
                    referrer1,
                    rate1,
                    referrer2,
                    rate2,
                    referrer3,
                    rate3
                )
            }
        }
    }

    function _doCommissionAndTrimToToken(
        CommissionInfo memory commissionInfo,
        address receiver,
        uint256 balanceBefore,
        address toToken,
        TrimInfo memory trimInfo
    ) internal override returns (uint256 totalAmount) {
        if (!commissionInfo.isToTokenCommission && !trimInfo.hasTrim) {
            return 0;
        }
        uint256 balanceAfter = _getBalanceOf(toToken, address(this));
        assembly ("memory-safe") {
            // https://github.com/Vectorized/solady/blob/701406e8126cfed931645727b274df303fbcd94d/src/utils/FixedPointMathLib.sol#L595
            function _mulDiv(x, y, d) -> z {
                z := mul(x, y)
                // Equivalent to `require(d != 0 && (y == 0 || x <= type(uint256).max / y))`.
                if iszero(mul(or(iszero(x), eq(div(z, x), y)), d)) {
                    mstore(0x00, 0xad251c27) // `MulDivFailed()`.
                    revert(0x1c, 0x04)
                }
                z := div(z, d)
            }
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
            function _sendETH(to, amount) {
                let success := call(gas(), to, amount, 0, 0, 0, 0)
                if eq(success, 0) {
                    _revertWithReason(
                        0x0000001173656e64206574686572206661696c65640000000000000000000000,
                        0x55
                    ) // "send ether failed"
                }
            }
            function _sendToken(token, to, amount) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x44))
                mstore(
                    freePtr,
                    0xa9059cbb00000000000000000000000000000000000000000000000000000000
                ) // transfer
                mstore(add(freePtr, 0x04), to)
                mstore(add(freePtr, 0x24), amount)
                let success := call(
                    gas(),
                    token,
                    0,
                    freePtr,
                    0x44,
                    0,
                    0x20
                )
                if and(
                    iszero(and(eq(mload(0), 1), gt(returndatasize(), 31))),
                    success
                ) {
                    success := iszero(
                        or(iszero(extcodesize(token)), returndatasize())
                    )
                }
                if eq(success, 0) {
                    _revertWithReason(
                        0x000000157472616e7366657220746f6b656e206661696c656400000000000000,
                        0x59
                    ) // "transfer token failed"
                }
            }
            function _emitCommissionToToken(token, amount, referrer) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x60))
                mstore(freePtr, token)
                mstore(add(freePtr, 0x20), amount)
                mstore(add(freePtr, 0x40), referrer)
                log1(
                    freePtr,
                    0x60,
                    0xf171268de859ec269c52bbfac94dcb7715e784de194342abb284bf34fd30b32d
                ) //emit CommissionToTokenRecord(address,uint256,address)
            }
            function _emitPositiveSlippageTrimRecord(token, trimAmount, trimAddress) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x60))
                mstore(freePtr, token)
                mstore(add(freePtr, 0x20), trimAmount)
                mstore(add(freePtr, 0x40), trimAddress)
                log1(
                    freePtr,
                    0x60,
                    0x7bec7d55a62a7a7b8068f1533e2a3bbf727b3e2e57f30c576fe159da60e09a65
                ) // emit PositiveSlippageTrimRecord(address,uint256,address)
            }
            function _emitPositiveSlippageChargeRecord(token, chargeAmount, chargeAddress) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x60))
                mstore(freePtr, token)
                mstore(add(freePtr, 0x20), chargeAmount)
                mstore(add(freePtr, 0x40), chargeAddress)
                log1(
                    freePtr,
                    0x60,
                    0xfd08115c8e43d2a49d95ee18d7f69b8bbac60bd368c73cf22d30664a22a0626d
                ) // emit PositiveSlippageChargeRecord(address,uint256,address)
            }
            function _processCommission(commissionInfo_, toToken_, inputAmount) -> commissionAmount {
                let rate1 := mload(add(commissionInfo_, 0x40)) // commissionInfo.commissionRate
                let rate2 := mload(add(commissionInfo_, 0xa0)) // commissionInfo.commissionRate2
                let rate3 := mload(add(commissionInfo_, 0x100)) // commissionInfo.commissionRate3
                let totalRate := add(add(rate1, rate2), rate3)
                if gt(totalRate, commissionRateLimit) {
                    _revertWithReason(
                        0x0000001b6572726f7220636f6d6d697373696f6e2072617465206c696d697400,
                        0x5f
                    ) // "error commission rate limit"
                }
                commissionAmount := _mulDiv(inputAmount, totalRate, DENOMINATOR)

                // send token and emit events
                let amount1 := _mulDiv(commissionAmount, rate1, totalRate)
                let amount2 := _mulDiv(commissionAmount, rate2, totalRate)
                let amount3 := sub(commissionAmount, add(amount1, amount2))
                switch eq(toToken_, _ETH)
                case 1 {
                    if gt(rate1, 0) {
                        let referrer1 := mload(add(commissionInfo_, 0x60)) // commissionInfo.refererAddress
                        _sendETH(referrer1, amount1)
                        _emitCommissionToToken(_ETH, amount1, referrer1)
                    }
                    if gt(rate2, 0) {
                        let referrer2 := mload(add(commissionInfo_, 0xc0)) // commissionInfo.refererAddress2
                        _sendETH(referrer2, amount2)
                        _emitCommissionToToken(_ETH, amount2, referrer2)
                    }
                    if gt(rate3, 0) {
                        let referrer3 := mload(add(commissionInfo_, 0x120)) // commissionInfo.refererAddress3
                        _sendETH(referrer3, amount3)
                        _emitCommissionToToken(_ETH, amount3, referrer3)
                    }
                }
                case 0 {
                    if gt(rate1, 0) {
                        let referrer1 := mload(add(commissionInfo_, 0x60)) // commissionInfo.refererAddress
                        _sendToken(toToken_, referrer1, amount1)
                        _emitCommissionToToken(toToken_, amount1, referrer1)
                    }
                    if gt(rate2, 0) {
                        let referrer2 := mload(add(commissionInfo_, 0xc0)) // commissionInfo.refererAddress2
                        _sendToken(toToken_, referrer2, amount2)
                        _emitCommissionToToken(toToken_, amount2, referrer2)
                    }
                    if gt(rate3, 0) {
                        let referrer3 := mload(add(commissionInfo_, 0x120)) // commissionInfo.refererAddress3
                        _sendToken(toToken_, referrer3, amount3)
                        _emitCommissionToToken(toToken_, amount3, referrer3)
                    }
                }
            } 
            function _processTrim(trimInfo_, toToken_, inputAmount) -> trimAmount {
                let trimRate := mload(add(trimInfo_, 0x20)) // trimInfo.trimRate
                let chargeRate := mload(add(trimInfo_, 0x80)) // trimInfo.chargeRate
                // require(trimInfo.trimRate <= TRIM_RATE_LIMIT, "error trim rate limit");
                if gt(trimRate, TRIM_RATE_LIMIT) {
                    _revertWithReason(
                        0x000000156572726f72207472696d2072617465206c696d697400000000000000,
                        0x59
                    ) // "error trim rate limit"
                }
                // require(trimInfo.chargeRate <= TRIM_DENOMINATOR, "error charge rate");
                if gt(chargeRate, TRIM_DENOMINATOR) {
                    _revertWithReason(
                        0x000000116572726f722063686172676520726174650000000000000000000000,
                        0x55
                    ) // "error charge rate"
                }
                // uint256 trimAmount = inputAmount - trimInfo.expectAmountOut;
                let expectAmountOut := mload(add(trimInfo_, 0x60)) // trimInfo.expectAmountOut
                trimAmount := sub(inputAmount, expectAmountOut)
                // uint256 allowedMaxTrimAmount = inputAmount * trimInfo.trimRate / TRIM_DENOMINATOR;
                let allowedMaxTrimAmount := _mulDiv(inputAmount, trimRate, TRIM_DENOMINATOR)
                // trimAmount = min(trimAmount, allowedMaxTrimAmount)
                if gt(trimAmount, allowedMaxTrimAmount) {
                    trimAmount := allowedMaxTrimAmount
                }

                // send token and emit events
                let amount1 := _mulDiv(trimAmount, sub(TRIM_DENOMINATOR, chargeRate), TRIM_DENOMINATOR)
                let amount2 := sub(trimAmount, amount1)
                switch eq(toToken_, _ETH)
                case 1 { // commission token is ETH
                    if gt(TRIM_DENOMINATOR, chargeRate) { // TRIM_DENOMINATOR - chargeRate > 0
                        // chargeAmount = trimAmount * (TRIM_DENOMINATOR - chargeRate) / TRIM_DENOMINATOR
                        let trimAddress := mload(add(trimInfo_, 0x40)) // trimInfo.trimAddress
                        _sendETH(trimAddress, amount1)
                        _emitPositiveSlippageTrimRecord(_ETH, amount1, trimAddress)
                    }
                    if gt(chargeRate, 0) {
                        let chargeAddress := mload(add(trimInfo_, 0xa0)) // trimInfo.chargeAddress
                        _sendETH(chargeAddress, amount2)
                        _emitPositiveSlippageChargeRecord(_ETH, amount2, chargeAddress)
                    }
                }
                case 0 { // commission token is ERC20
                    if gt(TRIM_DENOMINATOR, chargeRate) { // TRIM_DENOMINATOR - chargeRate > 0
                        let trimAddress := mload(add(trimInfo_, 0x40)) // trimInfo.trimAddress
                        _sendToken(toToken_, trimAddress, amount1)
                        _emitPositiveSlippageTrimRecord(toToken_, amount1, trimAddress)
                    }
                    if gt(chargeRate, 0) {
                        let chargeAddress := mload(add(trimInfo_, 0xa0)) // trimInfo.chargeAddress
                        _sendToken(toToken_, chargeAddress, amount2)
                        _emitPositiveSlippageChargeRecord(toToken_, amount2, chargeAddress)
                    }
                }
            }

            // require(balanceAfter >= balanceBefore, "invalid balance after");
            if gt(balanceBefore, balanceAfter) {
                _revertWithReason(
                    0x00000015696e76616c69642062616c616e636520616674657200000000000000,
                    0x59
                ) // "invalid balance after"
            }
            let inputAmount := sub(balanceAfter, balanceBefore)

            // process commission
            let flag := mload(add(commissionInfo, 0x20)) // commissionInfo.isToTokenCommission
            if gt(flag, 0) { // commissionInfo.isToTokenCommission == True
                let commissionAmount := _processCommission(commissionInfo, toToken, inputAmount)
                inputAmount := sub(inputAmount, commissionAmount)
                totalAmount := commissionAmount
            }

            // process trim
            flag := mload(add(trimInfo, 0x00)) // trimInfo.hasTrim
            let expectAmountOut := mload(add(trimInfo, 0x60)) // trimInfo.expectAmountOut
            if and(gt(flag, 0), gt(inputAmount, expectAmountOut)) { // trimInfo.hasTrim == True && inputAmount > trimInfo.expectAmountOut
                let trimAmount := _processTrim(trimInfo, toToken, inputAmount)
                inputAmount := sub(inputAmount, trimAmount)
                totalAmount := add(totalAmount, trimAmount)
            }

            // transfer toToken to receiver
            switch eq(toToken, _ETH)
            case 1 {
                _sendETH(shr(96, shl(96, receiver)), inputAmount)
            }
            default {
                _sendToken(toToken, shr(96, shl(96, receiver)), inputAmount)
            }
        }
    }

    function _validateCommissionInfo(
        CommissionInfo memory commissionInfo,
        address fromToken,
        address toToken,
        uint256 mode
    ) internal pure override {
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

            // if ((
            //     (mode & _MODE_NO_TRANSFER) != 0 
            // || (mode & _MODE_BY_INVEST) != 0
            // || (mode & _MODE_PERMIT2) != 0
            // )
            // && commissionInfo.isFromTokenCommission) {
            //     revert("From commission not support");
            // }
            let flag := or(
                or(
                    gt(and(mode, _MODE_NO_TRANSFER), 0),
                    gt(and(mode, _MODE_BY_INVEST), 0)
                ),
                gt(and(mode, _MODE_PERMIT2), 0)
            )
            let isFromTokenCommission := mload(add(commissionInfo, 0x00)) // commissionInfo.isFromTokenCommission
            if and(flag, isFromTokenCommission) {
                _revertWithReason(
                    0x0000001b46726f6d20636f6d6d697373696f6e206e6f7420737570706f727400,
                    0x5f
                ) // "From commission not support"
            }

            // if(fromToken == toToken) {
            //     revert("Invalid tokens");
            // }
            if eq(fromToken, toToken) {
                _revertWithReason(
                    0x0000000e496e76616c696420746f6b656e730000000000000000000000000000,
                    0x52
                ) // "Invalid tokens"
            }

            // if (commissionInfo.isFromTokenCommission && commissionInfo.isToTokenCommission) {
            //     revert("Invalid commission direction");
            // }
            let isToTokenCommission := mload(add(commissionInfo, 0x20)) // commissionInfo.isToTokenCommission
            if and(isToTokenCommission, isFromTokenCommission) {
                _revertWithReason(
                    0x0000001c496e76616c696420636f6d6d697373696f6e20646972656374696f6e,
                    0x60
                ) // "Invalid commission direction"
            }

            // require(
            //     (commissionInfo.isFromTokenCommission && commissionInfo.token == fromToken)
            //         || (commissionInfo.isToTokenCommission && commissionInfo.token == toToken)
            //         || (!commissionInfo.isFromTokenCommission && !commissionInfo.isToTokenCommission),
            //     "Invalid commission info"
            // );
            let token := mload(add(commissionInfo, 0x80)) // commissionInfo.token
            flag := and(isFromTokenCommission, eq(token, fromToken))
            flag := or(flag, and(isToTokenCommission, eq(token, toToken)))
            flag := or(flag, and(iszero(isFromTokenCommission), iszero(isToTokenCommission)))
            if iszero(flag) {
                _revertWithReason(
                    0x00000017496e76616c696420636f6d6d697373696f6e20696e666f0000000000,
                    0x5b
                ) // "Invalid commission info"
            }
        }
    }
}