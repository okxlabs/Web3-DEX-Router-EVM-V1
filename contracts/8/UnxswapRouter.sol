// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IUni.sol";

import "./libraries/UniversalERC20.sol";
import "./libraries/CommonUtils.sol";

contract UnxswapRouter is CommonUtils {
    uint256 private constant _IS_TOKEN0_TAX =
        0x1000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _IS_TOKEN1_TAX =
        0x2000000000000000000000000000000000000000000000000000000000000000;
    uint256 private constant _CLAIM_TOKENS_CALL_SELECTOR_32 =
        0x0a5ea46600000000000000000000000000000000000000000000000000000000;
    uint256 private constant _TRANSFER_DEPOSIT_SELECTOR =
        0xa9059cbbd0e30db0000000000000000000000000000000000000000000000000;
    uint256 private constant _SWAP_GETRESERVES_SELECTOR =
        0x022c0d9f0902f1ac000000000000000000000000000000000000000000000000;
    uint256 private constant _WITHDRAW_TRNASFER_SELECTOR =
        0x2e1a7d4da9059cbb000000000000000000000000000000000000000000000000;
    uint256 private constant _BALANCEOF_TOKEN0_SELECTOR =
        0x70a082310dfe1681000000000000000000000000000000000000000000000000;
    uint256 private constant _BALANCEOF_TOKEN1_SELECTOR =
        0x70a08231d21220a7000000000000000000000000000000000000000000000000;

    uint256 private constant _NUMERATOR_MASK =
        0x0000000000000000ffffffff0000000000000000000000000000000000000000;

    uint256 private constant _DENOMINATOR = 1_000_000_000;
    uint256 private constant _NUMERATOR_OFFSET = 160;

    //-------------------------------
    //------- Internal Functions ----
    //-------------------------------
    /// @notice Performs the internal logic for executing a swap using the Unxswap protocol.
    /// @param srcToken The token to be swapped.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of tokens that must be received for the swap to be valid, protecting against slippage.
    /// @param pools The array of pool identifiers that define the swap route.
    /// @param payer The address of the entity providing the source tokens for the swap.
    /// @param receiver The address that will receive the tokens after the swap.
    /// @return returnAmount The amount of tokens received from the swap.
    /// @dev This internal function encapsulates the core logic of the Unxswap token swap process. It is meant to be called by other external functions that set up the required parameters. The actual interaction with the Unxswap pools and the token transfer mechanics are implemented here.
    function _unxswapInternal(
        IERC20 srcToken,
        uint256 amount,
        uint256 minReturn,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools,
        address payer,
        address receiver
    ) internal returns (uint256 returnAmount) {
        assembly {
            // solhint-disable-line no-inline-assembly

            function revertWithReason(m, len) {
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
            function _getTokenAddr(emptyPtr, pair, selector) -> token {
                mstore(emptyPtr, selector)
                if iszero(
                    staticcall(
                        gas(),
                        pair,
                        add(0x04, emptyPtr),
                        0x04,
                        0x00,
                        0x20
                    )
                ) {
                    revertWithReason(
                        0x0000001067657420746f6b656e206661696c6564000000000000000000000000,
                        0x54
                    ) // "get token failed"
                }
                token := mload(0x00)
            }
            function _getBalanceOfToken0(emptyPtr, pair) -> token0, balance0 {
                mstore(emptyPtr, _BALANCEOF_TOKEN0_SELECTOR)
                if iszero(
                    staticcall(
                        gas(),
                        pair,
                        add(0x04, emptyPtr),
                        0x04,
                        0x00,
                        0x20
                    )
                ) {
                    revertWithReason(
                        0x00000012746f6b656e302063616c6c206661696c656400000000000000000000,
                        0x56
                    ) // "token0 call failed"
                }
                token0 := mload(0x00)
                mstore(add(0x04, emptyPtr), pair)
                if iszero(
                    staticcall(gas(), token0, emptyPtr, 0x24, 0x00, 0x20)
                ) {
                    revertWithReason(
                        0x0000001562616c616e63654f662063616c6c206661696c656400000000000000,
                        0x59
                    ) // "balanceOf call failed"
                }
                balance0 := mload(0x00)
            }
            function _getBalanceOfToken1(emptyPtr, pair) -> token1, balance1 {
                mstore(emptyPtr, _BALANCEOF_TOKEN1_SELECTOR)
                if iszero(
                    staticcall(
                        gas(),
                        pair,
                        add(0x04, emptyPtr),
                        0x04,
                        0x00,
                        0x20
                    )
                ) {
                    revertWithReason(
                        0x00000012746f6b656e312063616c6c206661696c656400000000000000000000,
                        0x56
                    ) // "token1 call failed"
                }
                token1 := mload(0x00)
                mstore(add(0x04, emptyPtr), pair)
                if iszero(
                    staticcall(gas(), token1, emptyPtr, 0x24, 0x00, 0x20)
                ) {
                    revertWithReason(
                        0x0000001562616c616e63654f662063616c6c206661696c656400000000000000,
                        0x59
                    ) // "balanceOf call failed"
                }
                balance1 := mload(0x00)
            }

            function swap(
                emptyPtr,
                swapAmount,
                pair,
                reversed,
                isToken0Tax,
                isToken1Tax,
                numerator,
                dst
            ) -> ret {
                mstore(emptyPtr, _SWAP_GETRESERVES_SELECTOR)
                if iszero(
                    staticcall(
                        gas(),
                        pair,
                        add(0x04, emptyPtr),
                        0x4,
                        0x00,
                        0x40
                    )
                ) {
                    // we only need the first 0x40 bytes, no need timestamp info
                    revertWithReason(
                        0x0000001472657365727665732063616c6c206661696c65640000000000000000,
                        0x58
                    ) // "reserves call failed"
                }
                let reserve0 := mload(0x00)
                let reserve1 := mload(0x20)

                switch reversed
                case 0 {
                    //swap token0 for token1
                    if isToken0Tax {
                        let token0, balance0 := _getBalanceOfToken0(
                            emptyPtr,
                            pair
                        )
                        swapAmount := sub(balance0, reserve0)
                    }
                }
                default {
                    //swap token1 for token0
                    if isToken1Tax {
                        let token1, balance1 := _getBalanceOfToken1(
                            emptyPtr,
                            pair
                        )
                        swapAmount := sub(balance1, reserve1)
                    }
                    let temp := reserve0
                    reserve0 := reserve1
                    reserve1 := temp
                }

                ret := mul(swapAmount, numerator)
                ret := div(
                    mul(ret, reserve1),
                    add(ret, mul(reserve0, _DENOMINATOR))
                )
                mstore(emptyPtr, _SWAP_GETRESERVES_SELECTOR)
                switch reversed
                case 0 {
                    mstore(add(emptyPtr, 0x04), 0)
                    mstore(add(emptyPtr, 0x24), ret)
                }
                default {
                    mstore(add(emptyPtr, 0x04), ret)
                    mstore(add(emptyPtr, 0x24), 0)
                }
                mstore(add(emptyPtr, 0x44), dst)
                mstore(add(emptyPtr, 0x64), 0x80)
                mstore(add(emptyPtr, 0x84), 0)
                if iszero(call(gas(), pair, 0, emptyPtr, 0xa4, 0, 0)) {
                    revertWithReason(
                        0x00000010737761702063616c6c206661696c6564000000000000000000000000,
                        0x54
                    ) // "swap call failed"
                }
            }

            let poolsOffset
            let poolsEndOffset
            {
                let len := pools.length
                poolsOffset := pools.offset //
                poolsEndOffset := add(poolsOffset, mul(len, 32))

                if eq(len, 0) {
                    revertWithReason(
                        0x000000b656d70747920706f6f6c73000000000000000000000000000000000000,
                        0x4e
                    ) // "empty pools"
                }
            }
            let emptyPtr := mload(0x40)
            let rawPair := calldataload(poolsOffset)
            switch eq(_ETH, srcToken)
            case 1 {
                // require callvalue() >= amount, lt: if x < y return 1，else return 0
                if eq(lt(callvalue(), amount), 1) {
                    revertWithReason(
                        0x00000011696e76616c6964206d73672e76616c75650000000000000000000000,
                        0x55
                    ) // "invalid msg.value"
                }

                mstore(emptyPtr, _TRANSFER_DEPOSIT_SELECTOR)
                if iszero(
                    call(gas(), _WETH, amount, add(emptyPtr, 0x04), 0x4, 0, 0)
                ) {
                    revertWithReason(
                        0x000000126465706f73697420455448206661696c656400000000000000000000,
                        0x56
                    ) // "deposit ETH failed"
                }
                mstore(add(0x04, emptyPtr), and(rawPair, _ADDRESS_MASK))
                mstore(add(0x24, emptyPtr), amount)
                if iszero(call(gas(), _WETH, 0, emptyPtr, 0x44, 0, 0x20)) {
                    revertWithReason(
                        0x000000147472616e736665722057455448206661696c65640000000000000000,
                        0x58
                    ) // "transfer WETH failed"
                }
            }
            default {
                if callvalue() {
                    revertWithReason(
                        0x00000011696e76616c6964206d73672e76616c75650000000000000000000000,
                        0x55
                    ) // "invalid msg.value"
                }

                mstore(emptyPtr, _CLAIM_TOKENS_CALL_SELECTOR_32)
                mstore(add(emptyPtr, 0x4), srcToken)
                mstore(add(emptyPtr, 0x24), payer)
                mstore(add(emptyPtr, 0x44), and(rawPair, _ADDRESS_MASK))
                mstore(add(emptyPtr, 0x64), amount)
                if iszero(
                    call(gas(), _APPROVE_PROXY, 0, emptyPtr, 0x84, 0, 0)
                ) {
                    revertWithReason(
                        0x00000012636c61696d20746f6b656e206661696c656400000000000000000000,
                        0x56
                    ) // "claim token failed"
                }
            }

            returnAmount := amount

            for {
                let i := add(poolsOffset, 0x20)
            } lt(i, poolsEndOffset) {
                i := add(i, 0x20)
            } {
                let nextRawPair := calldataload(i)

                returnAmount := swap(
                    emptyPtr,
                    returnAmount,
                    and(rawPair, _ADDRESS_MASK),
                    and(rawPair, _REVERSE_MASK),
                    and(rawPair, _IS_TOKEN0_TAX),
                    and(rawPair, _IS_TOKEN1_TAX),
                    shr(_NUMERATOR_OFFSET, and(rawPair, _NUMERATOR_MASK)),
                    and(nextRawPair, _ADDRESS_MASK)
                )

                rawPair := nextRawPair
            }
            let toToken
            switch and(rawPair, _WETH_MASK)
            case 0 {
                let beforeAmount
                switch and(rawPair, _REVERSE_MASK)
                case 0 {
                    if and(rawPair, _IS_TOKEN1_TAX) {
                        mstore(emptyPtr, _BALANCEOF_TOKEN1_SELECTOR)
                        if iszero(
                            staticcall(
                                gas(),
                                and(rawPair, _ADDRESS_MASK),
                                add(0x04, emptyPtr),
                                0x04,
                                0x00,
                                0x20
                            )
                        ) {
                            revertWithReason(
                                0x00000012746f6b656e312063616c6c206661696c656400000000000000000000,
                                0x56
                            ) // "token1 call failed"
                        }
                        toToken := mload(0)
                        mstore(add(0x04, emptyPtr), receiver)
                        if iszero(
                            staticcall(
                                gas(),
                                toToken,
                                emptyPtr,
                                0x24,
                                0x00,
                                0x20
                            )
                        ) {
                            revertWithReason(
                                0x00000015746f6b656e312062616c616e6365206661696c656400000000000000,
                                0x59
                            ) // "token1 balance failed"
                        }
                        beforeAmount := mload(0)
                    }
                }
                default {
                    if and(rawPair, _IS_TOKEN0_TAX) {
                        mstore(emptyPtr, _BALANCEOF_TOKEN0_SELECTOR)
                        if iszero(
                            staticcall(
                                gas(),
                                and(rawPair, _ADDRESS_MASK),
                                add(0x04, emptyPtr),
                                0x04,
                                0x00,
                                0x20
                            )
                        ) {
                            revertWithReason(
                                0x00000012746f6b656e302063616c6c206661696c656400000000000000000000,
                                0x56
                            ) // "token0 call failed"
                        }
                        toToken := mload(0)
                        mstore(add(0x04, emptyPtr), receiver)
                        if iszero(
                            staticcall(
                                gas(),
                                toToken,
                                emptyPtr,
                                0x24,
                                0x00,
                                0x20
                            )
                        ) {
                            revertWithReason(
                                0x00000015746f6b656e302062616c616e6365206661696c656400000000000000,
                                0x56
                            ) // "token0 balance failed"
                        }
                        beforeAmount := mload(0)
                    }
                }
                returnAmount := swap(
                    emptyPtr,
                    returnAmount,
                    and(rawPair, _ADDRESS_MASK),
                    and(rawPair, _REVERSE_MASK),
                    and(rawPair, _IS_TOKEN0_TAX),
                    and(rawPair, _IS_TOKEN1_TAX),
                    shr(_NUMERATOR_OFFSET, and(rawPair, _NUMERATOR_MASK)),
                    receiver
                )
                switch lt(0x0, toToken)
                case 1 {
                    mstore(emptyPtr, _BALANCEOF_TOKEN0_SELECTOR)
                    mstore(add(0x04, emptyPtr), receiver)
                    if iszero(
                        staticcall(gas(), toToken, emptyPtr, 0x24, 0x00, 0x20)
                    ) {
                        revertWithReason(
                            0x000000146765742062616c616e63654f66206661696c65640000000000000000,
                            0x58
                        ) // "get balanceOf failed"
                    }
                    returnAmount := sub(mload(0), beforeAmount)
                }
                default {
                    // set token0 addr for the non-safemoon token
                    switch and(rawPair, _REVERSE_MASK)
                    case 0 {
                        // get token1
                        toToken := _getTokenAddr(
                            emptyPtr,
                            and(rawPair, _ADDRESS_MASK),
                            _BALANCEOF_TOKEN1_SELECTOR
                        )
                    }
                    default {
                        // get token0
                        toToken := _getTokenAddr(
                            emptyPtr,
                            and(rawPair, _ADDRESS_MASK),
                            _BALANCEOF_TOKEN0_SELECTOR
                        )
                    }
                }
            }
            default {
                toToken := _ETH
                returnAmount := swap(
                    emptyPtr,
                    returnAmount,
                    and(rawPair, _ADDRESS_MASK),
                    and(rawPair, _REVERSE_MASK),
                    and(rawPair, _IS_TOKEN0_TAX),
                    and(rawPair, _IS_TOKEN1_TAX),
                    shr(_NUMERATOR_OFFSET, and(rawPair, _NUMERATOR_MASK)),
                    address()
                )

                mstore(emptyPtr, _WITHDRAW_TRNASFER_SELECTOR)
                mstore(add(emptyPtr, 0x08), _WNATIVE_RELAY)
                mstore(add(emptyPtr, 0x28), returnAmount)
                if iszero(
                    call(gas(), _WETH, 0, add(0x04, emptyPtr), 0x44, 0, 0x20)
                ) {
                    revertWithReason(
                        0x000000147472616e736665722057455448206661696c65640000000000000000,
                        0x58
                    ) // "transfer WETH failed"
                }
                mstore(add(emptyPtr, 0x04), returnAmount)
                if iszero(
                    call(gas(), _WNATIVE_RELAY, 0, emptyPtr, 0x24, 0, 0x20)
                ) {
                    revertWithReason(
                        0x00000013776974686472617720455448206661696c6564000000000000000000,
                        0x57
                    ) // "withdraw ETH failed"
                }
                if iszero(call(gas(), receiver, returnAmount, 0, 0, 0, 0)) {
                    revertWithReason(
                        0x000000137472616e7366657220455448206661696c6564000000000000000000,
                        0x57
                    ) // "transfer ETH failed"
                }
            }

        }
    }
}
