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
    uint256 internal constant _TO_B_COMMISSION_MASK =
        0x8000000000000000000000000000000000000000000000000000000000000000;

    event CommissionFromTokenRecord(
        address fromTokenAddress,
        uint256 commissionAmount,
        address referrerAddress
    );

    event CommissionToTokenRecord(
        address toTokenAddress,
        uint256 commissionAmount,
        address referrerAddress
    );

    // set default value can change when need.
    uint256 public constant commissionRateLimit = 30000000;
    uint public constant DENOMINATOR = 10 ** 9;
    uint constant WAD = 1 ether;

    function _getCommissionInfo()
        internal
        pure
        override
        returns (CommissionInfo memory commissionInfo)
    {
        assembly ("memory-safe") {
            // let freePtr := mload(0x40)
            // mstore(0x40, add(freePtr, 0x100))
            let commissionData := calldataload(sub(calldatasize(), 0x20))
            let flag := and(commissionData, _COMMISSION_FLAG_MASK)
            let isDualreferrers := or(
                eq(flag, FROM_TOKEN_COMMISSION_DUAL),
                eq(flag, TO_TOKEN_COMMISSION_DUAL)
            )
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
            switch eq(isDualreferrers, 1)
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
        address srcToken,
        address payer,
        address receiver,
        uint256 inputAmount
    ) internal override returns (address, uint256) {
        if (commissionInfo.isToTokenCommission) {
            return (
                address(this),
                _getBalanceOf(commissionInfo.token, address(this))
            );
        }
        if (!commissionInfo.isFromTokenCommission) {
            return (address(receiver), 0);
        }

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
            // a << 8 | b << 4 | c => 0xabc
            function _getStatus(token, isToB, hasNextRefer) -> d {
                let a := mul(eq(token, _ETH), 256)
                let b := mul(isToB, 16)
                let c := hasNextRefer
                d := add(a, add(b, c))
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
            // get balance, then scale amount1, amount2 according to balance
            function _sendTokenWithinBalance(token, to1, amount1, to2, amount2)
                -> amount1Scaled, amount2Scaled
            {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x48))
                mstore(
                    freePtr,
                    0xa9059cbba9059cbb70a082310000000000000000000000000000000000000000
                ) // transfer transfer balanceOf
                // balanceOf
                mstore(add(freePtr, 0x0c), address())
                let success := staticcall(
                    gas(),
                    token,
                    add(freePtr, 0x08),
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
                let amountTotal := add(amount1, amount2)
                amount1Scaled := _mulDiv(
                    _mulDiv(amount1, WAD, amountTotal),
                    balanceAfter,
                    WAD
                ) // WARNING: Precision issues may also exist!!
                if gt(amount1Scaled, balanceAfter) {
                    _revertWithReason(
                        0x00000015696e76616c696420616d6f756e74315363616c656400000000000000,
                        0x59
                    ) //invalid amount1Scaled
                }
                mstore(add(freePtr, 0x08), to1)
                mstore(add(freePtr, 0x28), amount1Scaled)
                success := call(
                    gas(),
                    token,
                    0,
                    add(freePtr, 0x4),
                    0x44,
                    0,
                    0x20
                )
                // https://github.com/transmissions11/solmate/blob/e5e0ed64c75e74974151780884e59071d026d84e/src/utils/SafeTransferLib.sol#L54
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

                if gt(to2, 0) {
                    amount2Scaled := _safeSub(balanceAfter, amount1Scaled)

                    mstore(add(freePtr, 0x04), to2)
                    mstore(add(freePtr, 0x24), amount2Scaled)
                    success := call(gas(), token, 0, freePtr, 0x44, 0, 0x20)
                    // https://github.com/transmissions11/solmate/blob/e5e0ed64c75e74974151780884e59071d026d84e/src/utils/SafeTransferLib.sol#L54
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

            let token, status
            {
                token := mload(add(commissionInfo, 0x80))
                let isToB := mload(add(commissionInfo, 0xe0))
                let hasNextRefer := gt(mload(add(commissionInfo, 0xa0)), 0)
                if eq(
                    or(
                        eq(token, srcToken),
                        and(eq(token, _ETH), eq(srcToken, 0))
                    ),
                    0
                ) {
                    _revertWithReason(
                        0x00000017746f6b656e20616e6420737263206e6f74206d617463680000000000,
                        0x5b
                    ) // "token and src not match"
                }
                status := _getStatus(token, isToB, hasNextRefer)
            }
            let referrer1, referrer2, amount1, amount2
            {
                let rate1 := mload(add(commissionInfo, 0x40))
                let rate2 := mload(add(commissionInfo, 0xa0))
                // let totalRate := add(rate, rate2)
                if gt(add(rate1, rate2), commissionRateLimit) {
                    _revertWithReason(
                        0x0000001b6572726f7220636f6d6d697373696f6e2072617465206c696d697400,
                        0x5f
                    ) //"error commission rate limit"
                }
                referrer1 := mload(add(commissionInfo, 0x60))
                amount1 := div(
                    mul(inputAmount, rate1),
                    sub(DENOMINATOR, add(rate1, rate2))
                )
                referrer2 := mload(add(commissionInfo, 0xc0))
                amount2 := div(
                    mul(inputAmount, rate2),
                    sub(DENOMINATOR, add(rate1, rate2))
                )
            }

            switch status
            case 0x100 {
                _sendETH(referrer1, amount1)
                _emitCommissionFromToken(_ETH, amount1, referrer1)
            }
            case 0x101 {
                _sendETH(referrer1, amount1)
                _emitCommissionFromToken(_ETH, amount1, referrer1)
                _sendETH(referrer2, amount2)
                _emitCommissionFromToken(_ETH, amount2, referrer2)
            }
            case 0x110 {
                _sendETH(referrer1, amount1)
                _emitCommissionFromToken(_ETH, amount1, referrer1)
            }
            case 0x111 {
                _sendETH(referrer1, amount1)
                _emitCommissionFromToken(_ETH, amount1, referrer1)
                _sendETH(referrer2, amount2)
                _emitCommissionFromToken(_ETH, amount2, referrer2)
            }
            case 0x000 {
                _claimToken(token, payer, referrer1, amount1)
                _emitCommissionFromToken(token, amount1, referrer1)
            }
            case 0x001 {
                _claimToken(token, payer, referrer1, amount1)
                _emitCommissionFromToken(token, amount1, referrer1)
                _claimToken(token, payer, referrer2, amount2)
                _emitCommissionFromToken(token, amount2, referrer2)
            }
            case 0x010 {
                _claimToken(token, payer, address(), amount1)
                // considering the tax token, we first transfer it into dexrouter, then check balance, after that
                // scaled amount accordingly
                let amount1Scaled, amount2Scaled := _sendTokenWithinBalance(
                    token,
                    referrer1,
                    amount1,
                    0,
                    0
                )
                _emitCommissionFromToken(token, amount1Scaled, referrer1)
            }
            case 0x011 {
                _claimToken(token, payer, address(), add(amount1, amount2))
                // considering the tax token, we first transfer it into dexrouter, then check balance, after that
                // scaled amount accordingly
                let amount1Scaled, amount2Scaled := _sendTokenWithinBalance(
                    token,
                    referrer1,
                    amount1,
                    referrer2,
                    amount2
                )
                _emitCommissionFromToken(token, amount1Scaled, referrer1)
                _emitCommissionFromToken(token, amount2Scaled, referrer2)
            }
            default {
                _revertWithReason(
                    0x0000000e696e76616c6964207374617475730000000000000000000000000000,
                    0x52
                ) // invalid status
            }
        }
        return (address(receiver), 0);
    }

    function _doCommissionToToken(
        CommissionInfo memory commissionInfo,
        address receiver,
        uint256 balanceBefore
    ) internal override returns (uint256 amount) {
        if (!commissionInfo.isToTokenCommission) {
            return 0;
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
            let rate := mload(add(commissionInfo, 0x40))
            let rate2 := mload(add(commissionInfo, 0xa0))
            if gt(add(rate, rate2), commissionRateLimit) {
                _revertWithReason(
                    0x0000001b6572726f7220636f6d6d697373696f6e2072617465206c696d697400,
                    0x5f
                ) //"error commission rate limit"
            }
            let token := mload(add(commissionInfo, 0x80))
            let referrer := mload(add(commissionInfo, 0x60))
            let eventPtr := mload(0x40)
            mstore(0x40, add(eventPtr, 0x60))

            switch eq(token, _ETH)
            case 1 {
                if lt(selfbalance(), balanceBefore) {
                    _revertWithReason(
                        0x0000000a737562206661696c6564000000000000000000000000000000000000,
                        0x4d
                    ) // sub failed
                }
                let inputAmount := sub(selfbalance(), balanceBefore)
                amount := div(mul(inputAmount, rate), DENOMINATOR)
                let success := call(gas(), referrer, amount, 0, 0, 0, 0)
                if eq(success, 0) {
                    _revertWithReason(
                        0x000000197472616e73666572206574682072656665726572206661696c000000,
                        0x5d
                    ) // transfer eth referrer fail
                }
                mstore(eventPtr, token)
                mstore(add(eventPtr, 0x20), amount)
                mstore(add(eventPtr, 0x40), referrer)
                log1(
                    eventPtr,
                    0x60,
                    0xf171268de859ec269c52bbfac94dcb7715e784de194342abb284bf34fd30b32d
                ) //emit CommissionToTokenRecord(address,uint256,address)
                if gt(rate2, 0) {
                    let referrer2 := mload(add(commissionInfo, 0xc0))
                    let amount2 := div(mul(inputAmount, rate2), DENOMINATOR)
                    amount := add(amount, amount2)
                    let success2 := call(gas(), referrer2, amount2, 0, 0, 0, 0)
                    if eq(success2, 0) {
                        _revertWithReason(
                            0x000000197472616e73666572206574682072656665726572206661696c000000,
                            0x5d
                        ) // transfer eth referrer fail
                    }
                    mstore(eventPtr, token)
                    mstore(add(eventPtr, 0x20), amount2)
                    mstore(add(eventPtr, 0x40), referrer2)
                    log1(
                        eventPtr,
                        0x60,
                        0xf171268de859ec269c52bbfac94dcb7715e784de194342abb284bf34fd30b32d
                    ) //emit CommissionToTokenRecord(address,uint256,address)
                }
                // The purpose of using shr(96, shl(96, receiver)) is to handle an edge case where the original order ID combined with the receiver address might be passed into this call. This combined value would be longer than a standard address length, which could cause the transfer to fail. The bit-shifting operations ensure we extract only the proper address portion by:
                // First shifting left by 96 bits (shl(96, receiver)) to align the address
                // Then shifting right by 96 bits (shr(96, ...)) to isolate the correct address value
                // This prevents potential failures by enforcing the correct address length.
                success := call(
                    gas(),
                    shr(96, shl(96, receiver)),
                    sub(inputAmount, amount),
                    0,
                    0,
                    0,
                    0
                )
                if eq(success, 0) {
                    _revertWithReason(
                        0x0000001a7472616e7366657220657468207265636569766572206661696c0000,
                        0x5e
                    ) // transfer eth receiver fail
                }
            }
            default {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x4c))
                mstore(
                    freePtr,
                    0xa9059cbba9059cbba9059cbb70a0823100000000000000000000000000000000
                ) // transfer transfer transfer balanceOf
                mstore(add(freePtr, 0x10), address())
                let success := staticcall(
                    gas(),
                    token,
                    add(freePtr, 0xc),
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
                if lt(balanceAfter, balanceBefore) {
                    _revertWithReason(
                        0x0000000a737562206661696c6564000000000000000000000000000000000000,
                        0x4d
                    ) // sub failed
                }
                let inputAmount := sub(balanceAfter, balanceBefore)
                amount := div(mul(inputAmount, rate), DENOMINATOR)
                mstore(add(freePtr, 0x0c), referrer)
                mstore(add(freePtr, 0x2c), amount)
                success := call(
                    gas(),
                    token,
                    0,
                    add(freePtr, 0x8),
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
                mstore(eventPtr, token)
                mstore(add(eventPtr, 0x20), amount)
                mstore(add(eventPtr, 0x40), referrer)
                log1(
                    eventPtr,
                    0x60,
                    0xf171268de859ec269c52bbfac94dcb7715e784de194342abb284bf34fd30b32d
                ) //emit CommissionToTokenRecord(address,uint256,address)
                if gt(rate2, 0) {
                    let referrer2 := mload(add(commissionInfo, 0xc0))
                    let amount2 := div(mul(inputAmount, rate2), DENOMINATOR)
                    amount := add(amount, amount2)
                    mstore(add(freePtr, 0x08), referrer2)
                    mstore(add(freePtr, 0x28), amount2)
                    success := call(
                        gas(),
                        token,
                        0,
                        add(freePtr, 0x4),
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
                    /// @notice emit ETH address is from commissionInfo.token, so it is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                    mstore(eventPtr, token)
                    mstore(add(eventPtr, 0x20), amount2)
                    mstore(add(eventPtr, 0x40), referrer2)
                    log1(
                        eventPtr,
                        0x60,
                        0xf171268de859ec269c52bbfac94dcb7715e784de194342abb284bf34fd30b32d
                    ) //emit CommissionToTokenRecord(address,uint256,address)
                }
                // The purpose of using shr(96, shl(96, receiver)) is to handle an edge case where the original order ID combined with the receiver address might be passed into this call. This combined value would be longer than a standard address length, which could cause the transfer to fail. The bit-shifting operations ensure we extract only the proper address portion by:
                // First shifting left by 96 bits (shl(96, receiver)) to align the address
                // Then shifting right by 96 bits (shr(96, ...)) to isolate the correct address value
                // This prevents potential failures by enforcing the correct address length.
                mstore(add(freePtr, 0x04), shr(96, shl(96, receiver)))
                mstore(add(freePtr, 0x24), sub(inputAmount, amount))
                success := call(gas(), token, 0, freePtr, 0x44, 0, 0x20)
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
                        0x0000001c7472616e7366657220746f6b656e207265636569766572206661696c,
                        0x60
                    ) //transfer token receiver fail
                }
            }
        }
    }
}
