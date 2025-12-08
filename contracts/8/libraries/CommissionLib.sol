/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CommonUtils.sol";
import "../interfaces/AbstractCommissionLib.sol";
/// @title Base contract with common permit handling logics

abstract contract CommissionLib is AbstractCommissionLib, CommonUtils {
    function _getExtraData()
        internal
        override
        returns (ExtraData memory)
    {
        CommissionInfo memory commissionInfo;
        TrimInfo memory trimInfo;
        Permit2Info memory permit2Info;
        address refundTo;

        permit2Info.amounts = new uint256[](1 + MAX_COMMISSION_MULTIPLE_NUM);
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
                eq(flag, FROM_TOKEN_COMMISSION_MULTIPLE),
                eq(flag, TO_TOKEN_COMMISSION_MULTIPLE)
            ) {
                referrerNum := 3 // default referrer num to load real encoded referrer num
            }
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
                commissionData := calldataload(sub(calldatasize(), 0x40))
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
                // For multiple commission mode, load the encoded commission length and validate
                if gt(referrerNum, 2) {
                    referrerNum := shr(240, and(commissionData, _COMMISSION_LENGTH_MASK))
                    // require(referrerNum >= MIN_COMMISSION_MULTIPLE_NUM && referrerNum <= MAX_COMMISSION_MULTIPLE_NUM, "invalid referrer num")
                    if or(lt(referrerNum, MIN_COMMISSION_MULTIPLE_NUM), gt(referrerNum, MAX_COMMISSION_MULTIPLE_NUM)) {
                        _revertWithReason(
                            0x0000001420696e76616c6964207265666572726572206e756d00000000000000,
                            0x59
                        ) // "invalid referrer num"
                    }
                }
                mstore(add(0x80, commissionInfo), referrerNum) //commissionLength
            }
            default {
                let eraseNum := add(mul(MAX_COMMISSION_MULTIPLE_NUM, 2), 3) // 2 * MAX_COMMISSION_MULTIPLE_NUM + 3: token, toBCommission, commissionLength and all commission pairs
                for { let i := 0 } lt(i, eraseNum) { i := add(i, 1) } {
                    mstore(add(add(commissionInfo, 0x40), mul(i, 0x20)), 0) // erase commissionInfo.token ~ all commission pairs
                }
            }
            if gt(referrerNum, 1) {
                for { let i := 1 } lt(i, MAX_COMMISSION_MULTIPLE_NUM) { i := add(i, 1) } {
                    switch lt(i, referrerNum) // if i < referrerNum, the i-th commission pair is valid
                    case 1 {
                        commissionData := calldataload(sub(calldatasize(), add(0x40, mul(i, 0x20))))
                        let flag2 := and(commissionData, _COMMISSION_FLAG_MASK)
                        if iszero(eq(flag, flag2)) {
                            _revertWithReason(
                                0x0000001720696e76616c696420636f6d6d697373696f6e20666c616700000000,
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
                    default { // if i >= referrerNum, the i-th commission pair is invalid, and erase it
                        mstore(add(add(0xa0, commissionInfo), mul(i, 0x40)), 0) // erase i-th commissionRate
                        mstore(add(add(0xc0, commissionInfo), mul(i, 0x40)), 0) // erase i-th referrerAddress
                    }
                }
            }
            // calculate offset based on referrerNum
            let offset := 0
            let permit2InfoOffset := 0
            if gt(referrerNum, 0) {
                offset := mul(add(referrerNum, 1), 0x20)
            }
            // get first bytes32 of trim data
            let trimData := calldataload(sub(calldatasize(), add(offset, 0x20)))
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
                trimData := calldataload(sub(calldatasize(), add(offset, 0x40)))
                let flag2 := and(trimData, _TRIM_FLAG_MASK)
                if iszero(eq(flag, flag2)) {
                    _revertWithReason(
                        0x0000001120696e76616c6964207472696d20666c616700000000000000000000,
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
                permit2InfoOffset := add(offset, 0x40)
            }
            default {
                mstore(add(0x20, trimInfo), 0) // trimRate
                mstore(add(0x40, trimInfo), 0) // trimAddress
                mstore(add(0x60, trimInfo), 0) // toBTrim
                mstore(add(0x80, trimInfo), 0) // expectAmountOut
                permit2InfoOffset := offset
            }
            switch eq(flag, TRIM_DUAL_FLAG)
            case 1 {
                // get third bytes32 of trim data
                trimData := calldataload(sub(calldatasize(), add(offset, 0x60)))
                let flag2 := and(trimData, _TRIM_FLAG_MASK)
                if iszero(eq(flag, flag2)) {
                    _revertWithReason(
                        0x0000001120696e76616c6964207472696d20666c616700000000000000000000,
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
                permit2InfoOffset := add(offset, 0x60)
            }
            default {
                mstore(add(0xa0, trimInfo), 0) // chargeRate
                mstore(add(0xc0, trimInfo), 0) // chargeAddress
            }
            // get first bytes32 of permit2Info
            let permit2InfoData := calldataload(sub(calldatasize(), add(permit2InfoOffset, 0x20)))
            let refundToOffset
            permit2InfoFlag := and(permit2InfoData, _PERMIT2_INFO_FLAG_MASK)
            if or(
                eq(permit2InfoFlag, PERMIT2_INFO_SIG65_FLAG),
                eq(permit2InfoFlag, PERMIT2_INFO_SIG64_FLAG)
            ) {
                let amountLength := shr(200, and(permit2InfoData, _PERMIT2_INFO_AMOUNT_LENGTH_MASK))
                mstore(permit2Info, and(permit2InfoData, _ADDRESS_MASK)) // owner

                // get second bytes32 of permit2Info
                permit2InfoData := calldataload(sub(calldatasize(), add(permit2InfoOffset, 0x40)))
                flag := and(permit2InfoData, _PERMIT2_INFO_FLAG_MASK)
                if iszero(eq(permit2InfoFlag, flag)) {
                    _revertWithReason(
                        0x0000001820696e76616c6964207065726d697432496e666f20666c6167000000,
                        0x5d
                    ) // "invalid permit2Info flag"
                }
                mstore(add(permit2Info, 0x20), and(permit2InfoData, _PERMIT2_INFO_NONCE_MASK)) // nonce
                mstore(add(permit2Info, 0x40), shr(48, and(permit2InfoData, _PERMIT2_INFO_DEADLINE_MASK))) // deadline
                if eq(permit2InfoFlag, PERMIT2_INFO_SIG65_FLAG) {
                    mstore(add(permit2SignatureCache, 0x60), shr(96, and(permit2InfoData, _PERMIT2_INFO_SIGNATURE_V_MASK))) // signature v
                }

                // get third bytes32 of permit2Info
                permit2InfoData := calldataload(sub(calldatasize(), add(permit2InfoOffset, 0x60)))
                mstore(add(permit2SignatureCache, 0x20), permit2InfoData) // signature r
                // get fourth bytes32 of permit2Info
                permit2InfoData := calldataload(sub(calldatasize(), add(permit2InfoOffset, 0x80)))
                mstore(add(permit2SignatureCache, 0x40), permit2InfoData) // signature s
                // get all amounts
                let amountsPosition := mload(add(permit2Info, 0x80))
                for { let i := 0 } lt(i, amountLength) { i := add(i, 1) } {
                    permit2InfoData := calldataload(sub(calldatasize(), add(permit2InfoOffset, add(0xa0, mul(i, 0x20)))))
                    mstore(add(amountsPosition, mul(add(i, 1), 0x20)), permit2InfoData) // permit2Info.amounts[i]
                }
                mstore(amountsPosition, amountLength) // reset length for amounts array

                // get refundTo offset
                refundToOffset := add(permit2InfoOffset, mul(add(4, amountLength), 0x20))
            }
            // decode refundTo
            let refundToData := calldataload(sub(calldatasize(), add(refundToOffset, 0x20)))
            if eq(and(refundToData, _REFUND_TO_MASK), REFUND_TO_ADDRESS_FLAG) {
                refundTo := and(refundToData, _ADDRESS_MASK)
            }
        }

        if (permit2InfoFlag == PERMIT2_INFO_SIG65_FLAG) {
            permit2Info.signature = abi.encodePacked(bytes32(permit2SignatureCache[0]), bytes32(permit2SignatureCache[1]), bytes1(uint8(permit2SignatureCache[2])));
        } else if (permit2InfoFlag == PERMIT2_INFO_SIG64_FLAG) {
            permit2Info.signature = abi.encodePacked(bytes32(permit2SignatureCache[0]), bytes32(permit2SignatureCache[1]));
        }

        if (commissionInfo.isFromTokenCommission || commissionInfo.isToTokenCommission || trimInfo.hasTrim) {
            emit CommissionAndTrimInfo(
                commissionInfo.toBCommission,
                trimInfo.toBTrim,
                trimInfo.trimRate,
                trimInfo.chargeRate
            );
        }

        return ExtraData({
            commissionInfo: commissionInfo,
            trimInfo: trimInfo,
            permit2Info: permit2Info,
            refundTo: refundTo
        });
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
                        0x00000014206765742062616c616e63654f66206661696c656400000000000000,
                        0x59
                    ) // "get balanceOf failed"
                }
                amount := mload(0x00)
            }
        }
    }

    function _doCommissionFromToken(
        CommissionInfo memory commissionInfo,
        SwapParams memory swapParams,
        uint256 fromTokenCommissionAmount,
        bool hasTrim
    ) internal override returns (address middleReceiver, uint256 balanceBefore) {
        if (commissionInfo.isToTokenCommission || hasTrim) {
            middleReceiver = address(this);
            balanceBefore = _getBalanceOf(swapParams.toToken, address(this));
        } else {
            middleReceiver = swapParams.receiver;
        }

        if (commissionInfo.isFromTokenCommission) {
            _doCommissionFromTokenInternal(commissionInfo, swapParams.payer, fromTokenCommissionAmount);
        }
    }

    /// @notice For ERC20 fromToken non-toB commission with PERMIT2_SIGNATURE mode, the commission token has been transferred to referrers earlier than here.
    ///         So for this situation, only need to emit event.
    function _doCommissionFromTokenInternal(
        CommissionInfo memory commissionInfo,
        address payer,
        uint256 fromTokenCommissionAmount
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
                if gt(amount, 0) {
                    let success := call(gas(), to, amount, 0, 0, 0, 0)
                    if eq(success, 0) {
                        _revertWithReason(
                            0x0000001b20636f6d6d697373696f6e2077697468206574686572206572726f72,
                            0x60
                        ) // "commission with ether error"
                    }
                }
            }
            function _claimToken(token, _payer, to, amount) {
                if gt(amount, 0) {
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
                            0x0000001320636c61696d20746f6b656e73206661696c65640000000000000000,
                            0x58
                        ) // "claim tokens failed"
                    }
                }
            }
            function _sendToken(token, to, amount) {
                if gt(amount, 0) {
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
                            0x0000001b207472616e7366657220746f6b656e2072656665726572206661696c,
                            0x60
                        ) // "transfer token referer fail"
                    }
                }
            }
            function _getBalanceOfToken(token) -> tokenBalance {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x24))
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
                        0x00000014206765742062616c616e63654f66206661696c656400000000000000,
                        0x59
                    ) // "get balanceOf failed"
                }
                tokenBalance := mload(0x00)
            }
            function _emitCommissionFromToken(token, amount, referrer, rate) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x80))
                mstore(freePtr, token)
                mstore(add(freePtr, 0x20), amount)
                mstore(add(freePtr, 0x40), referrer)
                mstore(add(freePtr, 0x60), rate)
                log1(
                    freePtr,
                    0x80,
                    0xcd5eae9d9d0b96532bd1b7dbf6628ce436b2af735829087a03c548439f8bf850
                ) //emit CommissionFromTokenRecord(address,uint256,address,uint256)
            }
            function _transferTokenDirect(token, from, to, amount) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x64)) // calldata size == 0x64
                mstore(
                    freePtr,
                    0x23b872dd00000000000000000000000000000000000000000000000000000000
                ) // transferFrom(address,address,uint256)
                mstore(add(freePtr, 0x04), from)
                mstore(add(freePtr, 0x24), to)
                mstore(add(freePtr, 0x44), amount)
                let success := call(
                    gas(),
                    token,
                    0,
                    freePtr,
                    0x64,
                    0,
                    0x20
                )
                if eq(success, 0) {
                    _revertWithReason(
                        0x0000001b207472616e7366657220746f6b656e2072656665726572206661696c,
                        0x60
                    ) // "transfer token referer fail"
                }
            }
            function _transferTokenPermit2Allowance(token, from, to, amount) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x84)) // calldata size == 0x84
                mstore(
                    freePtr,
                    0x36c7851600000000000000000000000000000000000000000000000000000000
                ) // transferFrom(address,address,uint160,address)
                mstore(add(freePtr, 0x04), from)
                mstore(add(freePtr, 0x24), to)
                mstore(add(freePtr, 0x44), shr(96, shl(96, amount)))
                mstore(add(freePtr, 0x64), token)
                let success := call(
                    gas(),
                    _PERMIT2,
                    0,
                    freePtr,
                    0x84,
                    0,
                    0
                )
                if eq(success, 0) {
                    _revertWithReason(
                        0x0000001b207472616e7366657220746f6b656e2072656665726572206661696c,
                        0x60
                    ) // "transfer token referer fail"
                }
            }
            function _transferTokenWithMode(token, mode, _payer, to, amount) {
                if gt(amount, 0) {
                    switch eq(_payer, address())
                    case 1{
                        _sendToken(token, to, amount)
                    }
                    default {
                        switch mode
                        case 0x0A00000000000000000000000000000000000000000000000000000000000000 { // _MODE_DIRECT
                            _transferTokenDirect(token, _payer, to, amount)
                        }
                        case 0x0200000000000000000000000000000000000000000000000000000000000000 { // _MODE_PERMIT2_ALLOWANCE
                            _transferTokenPermit2Allowance(token, _payer, to, amount)
                        }
                        case 0x0000000000000000000000000000000000000000000000000000000000000000 { // _MODE_LEGACY
                            _claimToken(token, _payer, to, amount)
                        }
                        default {
                            _revertWithReason(
                                0x0000001520696e76616c6964207472616e73666572206d6f6465000000000000,
                                0x5a
                            ) // "invalid transfer mode"
                        }
                    }
                }
            }

            let tokenWithMode := mload(add(commissionInfo, 0x40))
            let mode := and(tokenWithMode, _TRANSFER_MODE_MASK)
            let token := and(tokenWithMode, _ADDRESS_MASK)
            let toBCommission := mload(add(commissionInfo, 0x60))
            let totalRate := 0
            let referrerNum := mload(add(commissionInfo, 0x80))
            for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                let rate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                totalRate := add(totalRate, rate)
            }
            if gt(totalRate, commissionRateLimit) {
                _revertWithReason(
                    0x00000015206572726f7220636f6d6d697373696f6e2072617465000000000000,
                    0x5a
                ) // "error commission rate"
            }
            if eq(token, _ETH) { // commission token is ETH, the process is same between no toB mode and toB mode
                let sendAmount := 0
                for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                    let rate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                    let referrer := mload(add(commissionInfo, add(0xc0, mul(i, 0x40))))
                    let amount
                    switch eq(i, sub(referrerNum, 1))
                    case 1 {
                        amount := sub(fromTokenCommissionAmount, sendAmount)
                    }
                    default {
                        amount := div(
                            mul(fromTokenCommissionAmount, rate),
                            totalRate
                        )
                        sendAmount := add(sendAmount, amount)
                    }
                    _sendETH(referrer, amount)
                    _emitCommissionFromToken(_ETH, amount, referrer, rate)
                }
            }
            if iszero(eq(token, _ETH)) {
                let noNeedTransfer := and(eq(mode, _MODE_PERMIT2_SIGNATURE), eq(toBCommission, NO_TO_B_MODE)) // transferMode == _MODE_PERMIT2_SIGNATURE && ToC mode, the token has been transferred to referrers and no need to transfer again.
                if or(
                    and(eq(mode, _MODE_PERMIT2_SIGNATURE), eq(toBCommission, TO_B_MODE)), // transferMode == _MODE_PERMIT2_SIGNATURE && ToB mode, the token has been claimed to address(this)
                    eq(mode, _MODE_BY_INVEST) // transferMode == _MODE_BY_INVEST, the token has been transferred to address(this)
                ) {
                    // require(payer == address(), "invalid payer");
                    if iszero(eq(payer, address())) {
                        _revertWithReason(
                            0x0000000d20696e76616c69642070617965720000000000000000000000000000,
                            0x52
                        ) // "invalid payer"
                    }
                }
                // ToB mode && transferMode != _MODE_PERMIT2_SIGNATURE/BY_INVEST, the token needs to be claimed to address(this) first
                if and(eq(toBCommission, TO_B_MODE), iszero(or(eq(mode, _MODE_PERMIT2_SIGNATURE), eq(mode, _MODE_BY_INVEST)))) {
                    _transferTokenWithMode(token, mode, payer, address(), fromTokenCommissionAmount)
                    payer := address()
                    fromTokenCommissionAmount := _getBalanceOfToken(token)
                }
                // Execute the transfer to referrers
                let sendAmount := 0
                for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                    let rate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                    let referrer := mload(add(commissionInfo, add(0xc0, mul(i, 0x40))))
                    let amount
                    switch eq(i, sub(referrerNum, 1))
                    case 1 {
                        amount := sub(fromTokenCommissionAmount, sendAmount)
                    }
                    default {
                        amount := div(
                            mul(fromTokenCommissionAmount, rate),
                            totalRate
                        )
                        sendAmount := add(sendAmount, amount)
                    }
                    if iszero(noNeedTransfer) {
                        _transferTokenWithMode(token, mode, payer, referrer, amount)
                    }
                    _emitCommissionFromToken(token, amount, referrer, rate)
                }
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
                if gt(amount, 0) {
                    let success := call(gas(), to, amount, 0, 0, 0, 0)
                    if eq(success, 0) {
                        _revertWithReason(
                            0x000000112073656e64206574686572206661696c656400000000000000000000,
                            0x56
                        ) // "send ether failed"
                    }
                }
            }
            function _sendToken(token, to, amount) {
                if gt(amount, 0) {
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
                            0x00000015207472616e7366657220746f6b656e206661696c6564000000000000,
                            0x5a
                        ) // "transfer token failed"
                    }
                }
            }
            function _emitCommissionToToken(token, amount, referrer, rate) {
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x80))
                mstore(freePtr, token)
                mstore(add(freePtr, 0x20), amount)
                mstore(add(freePtr, 0x40), referrer)
                mstore(add(freePtr, 0x60), rate)
                log1(
                    freePtr,
                    0x80,
                    0x3cfb523a4c38d88561dd3bf04805a31715c8b5fc468a03b8d684356f360dea99
                ) //emit CommissionToTokenRecord(address,uint256,address,uint256)
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
                let referrerNum := mload(add(commissionInfo_, 0x80)) // commissionInfo.referrerNum
                let totalRate := 0
                for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                    let rate := mload(add(commissionInfo_, add(0xa0, mul(i, 0x40))))
                    totalRate := add(totalRate, rate)
                }
                if gt(totalRate, commissionRateLimit) {
                    _revertWithReason(
                        0x00000015206572726f7220636f6d6d697373696f6e2072617465000000000000,
                        0x5a
                    ) // "error commission rate"
                }
                commissionAmount := 0
                switch eq(toToken_, _ETH)
                case 1 { // commission token is ETH
                    for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                        let rate := mload(add(commissionInfo_, add(0xa0, mul(i, 0x40))))
                        let amount := _mulDiv(inputAmount, rate, DENOMINATOR)
                        let referrer := mload(add(commissionInfo_, add(0xc0, mul(i, 0x40))))
                        _sendETH(referrer, amount)
                        _emitCommissionToToken(_ETH, amount, referrer, rate)
                        commissionAmount := add(commissionAmount, amount)
                    }
                }
                default { // commission token is ERC20
                    for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                        let rate := mload(add(commissionInfo_, add(0xa0, mul(i, 0x40))))
                        let amount := _mulDiv(inputAmount, rate, DENOMINATOR)
                        let referrer := mload(add(commissionInfo_, add(0xc0, mul(i, 0x40))))
                        _sendToken(toToken_, referrer, amount)
                        _emitCommissionToToken(toToken_, amount, referrer, rate)
                        commissionAmount := add(commissionAmount, amount)
                    }
                }
            } 
            function _processTrim(trimInfo_, toToken_, inputAmount) -> trimAmount {
                let trimRate := mload(add(trimInfo_, 0x20)) // trimInfo.trimRate
                let chargeRate := mload(add(trimInfo_, 0xa0)) // trimInfo.chargeRate
                // require(trimInfo.trimRate <= TRIM_RATE_LIMIT, "error trim rate");
                if gt(trimRate, TRIM_RATE_LIMIT) {
                    _revertWithReason(
                        0x0000000f206572726f72207472696d2072617465000000000000000000000000,
                        0x54
                    ) // "error trim rate"
                }
                // require(trimInfo.chargeRate <= TRIM_DENOMINATOR, "error charge rate");
                if gt(chargeRate, TRIM_DENOMINATOR) {
                    _revertWithReason(
                        0x00000011206572726f7220636861726765207261746500000000000000000000,
                        0x56
                    ) // "error charge rate"
                }
                // uint256 trimAmount = inputAmount - trimInfo.expectAmountOut;
                let expectAmountOut := mload(add(trimInfo_, 0x80)) // trimInfo.expectAmountOut
                trimAmount := sub(inputAmount, expectAmountOut)
                // uint256 allowedMaxTrimAmount = inputAmount * trimInfo.trimRate / TRIM_DENOMINATOR;
                let allowedMaxTrimAmount := _mulDiv(inputAmount, trimRate, TRIM_DENOMINATOR)
                // trimAmount = min(trimAmount, allowedMaxTrimAmount)
                if gt(trimAmount, allowedMaxTrimAmount) {
                    trimAmount := allowedMaxTrimAmount
                }

                // send token and emit events
                // actualChargeAmount = trimAmount * chargeRate / TRIM_DENOMINATOR
                let actualChargeAmount := _mulDiv(trimAmount, chargeRate, TRIM_DENOMINATOR)
                // actualTrimAmount = trimAmount - actualChargeAmount
                let actualTrimAmount := sub(trimAmount, actualChargeAmount)
                switch eq(toToken_, _ETH)
                case 1 { // commission token is ETH
                    let trimAddress := mload(add(trimInfo_, 0x40)) // trimInfo.trimAddress
                    _sendETH(trimAddress, actualTrimAmount)
                    _emitPositiveSlippageTrimRecord(_ETH, actualTrimAmount, trimAddress)

                    let chargeAddress := mload(add(trimInfo_, 0xc0)) // trimInfo.chargeAddress
                    _sendETH(chargeAddress, actualChargeAmount)
                    _emitPositiveSlippageChargeRecord(_ETH, actualChargeAmount, chargeAddress)
                }
                case 0 { // commission token is ERC20
                    let trimAddress := mload(add(trimInfo_, 0x40)) // trimInfo.trimAddress
                    _sendToken(toToken_, trimAddress, actualTrimAmount)
                    _emitPositiveSlippageTrimRecord(toToken_, actualTrimAmount, trimAddress)

                    let chargeAddress := mload(add(trimInfo_, 0xc0)) // trimInfo.chargeAddress
                    _sendToken(toToken_, chargeAddress, actualChargeAmount)
                    _emitPositiveSlippageChargeRecord(toToken_, actualChargeAmount, chargeAddress)
                }
            }

            // require(balanceAfter > balanceBefore, "invalid balance after");
            if or(gt(balanceBefore, balanceAfter), eq(balanceAfter, balanceBefore)) {
                _revertWithReason(
                    0x0000001520696e76616c69642062616c616e6365206166746572000000000000,
                    0x5a
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
            let expectAmountOut := mload(add(trimInfo, 0x80)) // trimInfo.expectAmountOut
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

            // if (mode == _MODE_NO_TRANSFER && commissionInfo.isFromTokenCommission) {
            //     revert("From commission not support");
            // }
            let isFromTokenCommission := mload(add(commissionInfo, 0x00)) // commissionInfo.isFromTokenCommission
            if and(eq(mode, _MODE_NO_TRANSFER), isFromTokenCommission) {
                _revertWithReason(
                    0x0000001b2046726f6d20636f6d6d697373696f6e206e6f7420737570706f7274,
                    0x60
                ) // "From commission not support"
            }

            // if(fromToken == toToken) {
            //     revert("Invalid tokens");
            // }
            if eq(fromToken, toToken) {
                _revertWithReason(
                    0x0000000e20496e76616c696420746f6b656e7300000000000000000000000000,
                    0x53
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
            let token := and(mload(add(commissionInfo, 0x40)), _ADDRESS_MASK) // commissionInfo.token
            let flag := and(isFromTokenCommission, eq(token, fromToken))
            flag := or(flag, and(isToTokenCommission, eq(token, toToken)))
            flag := or(flag, and(iszero(isFromTokenCommission), iszero(isToTokenCommission)))
            if iszero(flag) {
                _revertWithReason(
                    0x0000001720496e76616c696420636f6d6d697373696f6e20696e666f00000000,
                    0x5c
                ) // "Invalid commission info"
            }
        }
    }
}