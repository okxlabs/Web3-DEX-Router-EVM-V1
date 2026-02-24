/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./CommonLib.sol";
import "../interfaces/IDexRouter.sol";

library CommissionLib {
    /// @notice swapCache.refundTo is not used in this function.
    function doCommissionFromToken(
        IDexRouter.CommissionInfo memory commissionInfo,
        IDexRouter.SwapCache memory swapCache,
        uint256 fromTokenCommissionAmount,
        bool hasTrim
    ) internal returns (address middleReceiver, uint256 balanceBefore) {
        if (commissionInfo.isToTokenCommission || hasTrim) {
            middleReceiver = address(this);
            balanceBefore = CommonLib.getBalanceOf(swapCache.toToken, address(this));
        } else {
            middleReceiver = swapCache.receiver;
        }

        if (commissionInfo.isFromTokenCommission) {
            _doCommissionFromTokenInternal(commissionInfo, swapCache.payer, fromTokenCommissionAmount);
        }
    }

    /// @notice For ERC20 fromToken non-toB commission with PERMIT2_SIGNATURE mode, the commission token has been transferred to referrers earlier than here.
    ///         So for this situation, only need to emit event.
    function _doCommissionFromTokenInternal(
        IDexRouter.CommissionInfo memory commissionInfo,
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
                    let success := call(NATIVE_TOKEN_TRANSFER_GAS_LIMIT, to, amount, 0, 0, 0, 0)
                    if eq(success, 0) {
                        _revertWithReason(
                            0x0000001c20636f6d6d697373696f6e2077697468206574686572206572726f72,
                            0x60
                        ) // "commission with ether error"
                    }
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
                        0x0000001420636c61696d20746f6b656e73206661696c65640000000000000000,
                        0x58
                    ) // "claim tokens failed"
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
                            0x0000001c207472616e7366657220746f6b656e2072656665726572206661696c,
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
                        0x00000015206765742062616c616e63654f66206661696c656400000000000000,
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
                        0x0000001b207472616e7366657220746f6b656e20646972656374206661696c00,
                        0x5f
                    ) // "transfer token direct fail"
                }
            }
            function _transferTokenPermit2Allowance(token, from, to, amount) {
                // Check if amount exceeds uint160 max
                if shr(160, amount) {
                    _revertWithReason(
                        0x0000001120616d6f756e7420746f6f206c617267650000000000000000000000,
                        0x55
                    ) // "amount too large"
                }
                let freePtr := mload(0x40)
                mstore(0x40, add(freePtr, 0x84)) // calldata size == 0x84
                mstore(
                    freePtr,
                    0x36c7851600000000000000000000000000000000000000000000000000000000
                ) // transferFrom(address,address,uint160,address)
                mstore(add(freePtr, 0x04), from)
                mstore(add(freePtr, 0x24), to)
                mstore(add(freePtr, 0x44), amount)
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
                        0x0000001c7065726d69743220616c6c6f77616e6365207472616e73206661696c,
                        0x60
                    ) // "permit2 allowance trans fail"
                }
            }
            function _transferTokenWithMode(token, mode, _payer, to, amount) {
                if gt(amount, 0) {
                    // _payer has been set to address(this), means the token has been transferred to address(this).
                    if eq(_payer, address()) {
                        _sendToken(token, to, amount)
                    }
                    // _payer != address(this) && _payer != address(0), means the token has not been transferred yet.
                    if iszero(or(eq(_payer, address()), eq(_payer, 0))) {
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
                        amount := _mulDiv(fromTokenCommissionAmount, rate, totalRate)
                        sendAmount := add(sendAmount, amount)
                    }
                    _sendETH(referrer, amount)
                    _emitCommissionFromToken(_ETH, amount, referrer, rate)
                }
            }
            if iszero(eq(token, _ETH)) {
                if and(eq(toBCommission, TO_B_MODE), eq(mode, _MODE_PERMIT2_SIGNATURE)) { // ToB mode && transferMode == _MODE_PERMIT2_SIGNATURE, the token should have been claimed to address(this)
                    // require(payer == address(), "invalid payer");
                    if iszero(eq(payer, address())) {
                        _revertWithReason(
                            0x0000000e20696e76616c69642070617965720000000000000000000000000000,
                            0x52
                        ) // "invalid payer"
                    }
                }
                // ToB mode && transferMode != _MODE_PERMIT2_SIGNATURE, the token needs to be claimed from payer to address(this) first
                if and(eq(toBCommission, TO_B_MODE), iszero(eq(mode, _MODE_PERMIT2_SIGNATURE))) {
                    _transferTokenWithMode(token, mode, payer, address(), fromTokenCommissionAmount)
                    payer := address()
                    fromTokenCommissionAmount := _getBalanceOfToken(token)
                }

                // For ToC mode && transferMode == _MODE_PERMIT2_SIGNATURE, the commission has already been transferred via Permit2 batch transfer.
                // In this case, we only need to emit events, not transfer again.
                let skipTransfer := and(eq(toBCommission, NO_TO_B_MODE), eq(mode, _MODE_PERMIT2_SIGNATURE))

                // Execute the transfer to referrers (or just emit events if skipTransfer is true)
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
                        amount := _mulDiv(fromTokenCommissionAmount, rate, totalRate)
                        sendAmount := add(sendAmount, amount)
                    }

                    // Only transfer if not in PERMIT2_SIGNATURE && ToC mode case
                    if iszero(skipTransfer) {
                        _transferTokenWithMode(token, mode, payer, referrer, amount)
                    }
                    _emitCommissionFromToken(token, amount, referrer, rate)
                }
            }
        }
    }

    function doCommissionAndTrimToToken(
        IDexRouter.CommissionInfo memory commissionInfo,
        address receiver,
        uint256 balanceBefore,
        address toToken,
        IDexRouter.TrimInfo memory trimInfo
    ) internal returns (uint256 totalAmount) {
        if (!commissionInfo.isToTokenCommission && !trimInfo.hasTrim) {
            return 0;
        }
        uint256 balanceAfter = CommonLib.getBalanceOf(toToken, address(this));
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
                    let success := call(NATIVE_TOKEN_TRANSFER_GAS_LIMIT, to, amount, 0, 0, 0, 0)
                    if eq(success, 0) {
                        _revertWithReason(
                            0x000000122073656e64206574686572206661696c656400000000000000000000,
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
                            0x00000016207472616e7366657220746f6b656e206661696c6564000000000000,
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
                        0x00000010206572726f72207472696d2072617465000000000000000000000000,
                        0x54
                    ) // "error trim rate"
                }
                // require(trimInfo.chargeRate <= TRIM_DENOMINATOR, "error charge rate");
                if gt(chargeRate, TRIM_DENOMINATOR) {
                    _revertWithReason(
                        0x00000012206572726f7220636861726765207261746500000000000000000000,
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
                    0x0000001620696e76616c69642062616c616e6365206166746572000000000000,
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

    function validateCommissionInfo(
        IDexRouter.CommissionInfo memory commissionInfo,
        address fromToken,
        address toToken,
        uint256 mode
    ) internal pure {
        if (mode == _MODE_NO_TRANSFER && commissionInfo.isFromTokenCommission) {
            revert("From commission not support for NO_TRANSFER mode");
        }

        if (mode == _MODE_BY_INVEST && (commissionInfo.isFromTokenCommission || commissionInfo.isToTokenCommission)) {
            revert("Commission not support for BY_INVEST mode");
        }

        if (fromToken == toToken) {
            revert("Invalid tokens");
        }

        if (commissionInfo.isFromTokenCommission && commissionInfo.isToTokenCommission) {
            revert("Invalid commission direction");
        }

        address token = CommonLib.bytes32ToAddress(commissionInfo.tokenWithMode);
        require(
            (commissionInfo.isFromTokenCommission && token == fromToken)
                || (commissionInfo.isToTokenCommission && token == toToken)
                || (!commissionInfo.isFromTokenCommission && !commissionInfo.isToTokenCommission),
            "Invalid commission info"
        );

        uint256 totalRate = calculateTotalRate(commissionInfo);
        require(totalRate <= COMMISSION_RATE_LIMIT, "Invalid commission rate");

        // Validate referrer addresses are not zero
        for (uint256 i = 0; i < commissionInfo.commissionLength; ++i) {
            address referrerAddress;
            assembly ("memory-safe") {
                referrerAddress := mload(add(commissionInfo, add(0xc0, mul(i, 0x40))))
            }
            require(referrerAddress != address(0), "Invalid referrer address");
        }
    }

    function calculateTotalRate(IDexRouter.CommissionInfo memory commissionInfo) internal pure returns (uint256 totalRate) {
        assembly ("memory-safe") {
            let referrerNum := mload(add(commissionInfo, 0x80))
            for { let i := 0 } lt(i, referrerNum) { i := add(i, 1) } {
                let rate := mload(add(commissionInfo, add(0xa0, mul(i, 0x40))))
                totalRate := add(totalRate, rate)
            }
        }
    }
}