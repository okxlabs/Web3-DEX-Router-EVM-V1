/// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./interfaces/IUniswapV3SwapCallback.sol";
import "./interfaces/IUniV3.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IWNativeRelayer.sol";

import "./libraries/Address.sol";
import "./libraries/CommonUtils.sol";
import "./libraries/RouterErrors.sol";
import "./libraries/SafeCast.sol";

contract UnxswapV3Router is IUniswapV3SwapCallback, CommonUtils {
    using Address for address payable;

    bytes32 private constant _POOL_INIT_CODE_HASH =
        0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54; // Pool init code hash
    bytes32 private constant _FF_FACTORY = 0xff1F98431c8aD98523631AE4a59f267346ea31F9840000000000000000000000; // Factory address
    // concatenation of token0(), token1() fee(), transfer() and claimTokens() selectors
    bytes32 private constant _SELECTORS =
        0x0dfe1681d21220a7ddca3f43a9059cbb0a5ea466000000000000000000000000;
    // concatenation of withdraw(uint),transfer()
    bytes32 private constant _SELECTORS2 =
        0x2e1a7d4da9059cbb000000000000000000000000000000000000000000000000;
    bytes32 private constant _SELECTORS3 =
        0xa9059cbb70a08231000000000000000000000000000000000000000000000000;
    uint160 private constant _MIN_SQRT_RATIO = 4_295_128_739 + 1;
    uint160 private constant _MAX_SQRT_RATIO =
        1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342 - 1;
    bytes32 private constant _SWAP_SELECTOR =
        0x128acb0800000000000000000000000000000000000000000000000000000000; // Swap function selector
    uint256 private constant _INT256_MAX =
        0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff; // Maximum int256
    uint256 private constant _INT256_MIN =
        0x8000000000000000000000000000000000000000000000000000000000000000; // Minimum int256

    /// @notice Conducts a swap using the Uniswap V3 protocol internally within the contract.
    /// @param payer The address of the account providing the tokens for the swap.
    /// @param receiver The address that will receive the tokens after the swap.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of tokens that must be received for the swap to be valid, safeguarding against excessive slippage.
    /// @param pools An array of pool identifiers defining the swap route within Uniswap V3.
    /// @return returnAmount The amount of tokens received from the swap.
    /// @dev This internal function encapsulates the core logic for executing swaps on Uniswap V3. It is intended to be used by other functions in the contract that prepare and pass the necessary parameters. The function handles the swapping process, ensuring that the minimum return is met and managing the transfer of tokens.
    function _uniswapV3Swap(
        address payer,
        address payable receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) internal returns (uint256 returnAmount) {
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
            function _makeSwap(_receiver, _payer, _refundTo, _pool, _amount)
                -> _returnAmount
            {
                if lt(_INT256_MAX, _amount) {
                    mstore(
                        0,
                        0xb3f79fd000000000000000000000000000000000000000000000000000000000
                    ) //SafeCastToInt256Failed()
                    revert(0, 4)
                }
                let freePtr := mload(0x40)
                let zeroForOne := eq(and(_pool, _ONE_FOR_ZERO_MASK), 0)

                let poolAddr := and(_pool, _ADDRESS_MASK)
                switch zeroForOne
                case 1 {
                    mstore(freePtr, _SWAP_SELECTOR)
                    let paramPtr := add(freePtr, 4)
                    mstore(paramPtr, _receiver)
                    mstore(add(paramPtr, 0x20), true)
                    mstore(add(paramPtr, 0x40), _amount)
                    mstore(add(paramPtr, 0x60), _MIN_SQRT_RATIO)
                    mstore(add(paramPtr, 0x80), 0xa0)
                    mstore(add(paramPtr, 0xa0), 64)
                    mstore(add(paramPtr, 0xc0), _payer)
                    mstore(add(paramPtr, 0xe0), _refundTo)
                    let success := call(
                        gas(),
                        poolAddr,
                        0,
                        freePtr,
                        0x104,
                        0,
                        0
                    )
                    if iszero(success) {
                        revert(0, 32)
                    }
                    returndatacopy(0, 32, 32) // only copy _amount1   MEM[0:] <= RETURNDATA[32:32+32]
                }
                default {
                    mstore(freePtr, _SWAP_SELECTOR)
                    let paramPtr := add(freePtr, 4)
                    mstore(paramPtr, _receiver)
                    mstore(add(paramPtr, 0x20), false)
                    mstore(add(paramPtr, 0x40), _amount)
                    mstore(add(paramPtr, 0x60), _MAX_SQRT_RATIO)
                    mstore(add(paramPtr, 0x80), 0xa0)
                    mstore(add(paramPtr, 0xa0), 64)
                    mstore(add(paramPtr, 0xc0), _payer)
                    mstore(add(paramPtr, 0xe0), _refundTo)
                    let success := call(
                        gas(),
                        poolAddr,
                        0,
                        freePtr,
                        0x104,
                        0,
                        0
                    )
                    if iszero(success) {
                        revert(0, 32)
                    }
                    returndatacopy(0, 0, 32) // only copy _amount0   MEM[0:] <= RETURNDATA[0:0+32]
                }
                _returnAmount := mload(0)
                if lt(_returnAmount, _INT256_MIN) {
                    mstore(
                        0,
                        0x88c8ee9c00000000000000000000000000000000000000000000000000000000
                    ) //SafeCastToUint256Failed()
                    revert(0, 4)
                }
                _returnAmount := add(1, not(_returnAmount)) // -a = ~a + 1
            }
            function _wrapWeth(_amount) {
                // require callvalue() >= amount, lt: if x < y return 1，else return 0
                if eq(lt(callvalue(), _amount), 1) {
                    mstore(
                        0,
                        0x1841b4e100000000000000000000000000000000000000000000000000000000
                    ) // InvalidMsgValue()
                    revert(0, 4)
                }

                let success := call(gas(), _WETH, _amount, 0, 0, 0, 0) //进入fallback逻辑
                if iszero(success) {
                    _revertWithReason(
                        0x0000001357455448206465706f736974206661696c6564000000000000000000,
                        87
                    ) //WETH deposit failed
                }
            }
            function _unWrapWeth(_receiver, _amount) {
                let freePtr := mload(0x40)
                let transferPtr := add(freePtr, 4)

                mstore(freePtr, _SELECTORS2) // withdraw amountWith to amount
                // transfer
                mstore(add(transferPtr, 4), _WNATIVE_RELAY)
                mstore(add(transferPtr, 36), _amount)
                let success := call(gas(), _WETH, 0, transferPtr, 68, 0, 0)
                if iszero(success) {
                    _revertWithReason(
                        0x000000147472616e736665722077657468206661696c65640000000000000000,
                        88
                    ) // transfer weth failed
                }
                // withdraw
                mstore(add(freePtr, 4), _amount)
                success := call(gas(), _WNATIVE_RELAY, 0, freePtr, 36, 0, 0)
                if iszero(success) {
                    _revertWithReason(
                        0x0000001477697468647261772077657468206661696c65640000000000000000,
                        88
                    ) // withdraw weth failed
                }
                // msg.value transfer
                success := call(gas(), _receiver, _amount, 0, 0, 0, 0)
                if iszero(success) {
                    _revertWithReason(
                        0x0000001173656e64206574686572206661696c65640000000000000000000000,
                        85
                    ) // send ether failed
                }
            }
            function _token0(_pool) -> token0 {
                let freePtr := mload(0x40)
                mstore(freePtr, _SELECTORS)
                let success := staticcall(gas(), _pool, freePtr, 0x4, 0, 0)
                if iszero(success) {
                    _revertWithReason(
                        0x0000001167657420746f6b656e30206661696c65640000000000000000000000,
                        85
                    ) // get token0 failed
                }
                returndatacopy(0, 0, 32)
                token0 := mload(0)
            }
            function _token1(_pool) -> token1 {
                let freePtr := mload(0x40)
                mstore(freePtr, _SELECTORS)
                let success := staticcall(
                    gas(),
                    _pool,
                    add(freePtr, 4),
                    0x4,
                    0,
                    0
                )
                if iszero(success) {
                    _revertWithReason(
                        0x0000001167657420746f6b656e31206661696c65640000000000000000000000,
                        84
                    ) // get token1 failed
                }
                returndatacopy(0, 0, 32)
                token1 := mload(0)
            }

            let firstPoolStart
            let lastPoolStart

            {
                let len := pools.length
                firstPoolStart := pools.offset //
                lastPoolStart := sub(add(firstPoolStart, mul(len, 32)), 32)

                if eq(len, 0) {
                    mstore(
                        0,
                        0x67e7c0f600000000000000000000000000000000000000000000000000000000
                    ) // EmptyPools()
                    revert(0, 4)
                }
            }
            let refundTo := payer
            {
                let wrapWeth := gt(callvalue(), 0)
                if wrapWeth {
                    _wrapWeth(amount)
                    payer := address()
                }
            }

            mstore(96, amount) // 96 is not override by _makeSwap, since it only use freePtr memory, and it is not override by unWrapWeth ethier
            for {
                let i := firstPoolStart
            } lt(i, lastPoolStart) {
                i := add(i, 32)
            } {
                amount := _makeSwap(
                    address(),
                    payer,
                    refundTo,
                    calldataload(i),
                    amount
                )
                payer := address()
            }
            {
                let unwrapWeth := gt(
                    and(calldataload(lastPoolStart), _WETH_UNWRAP_MASK),
                    0
                ) // pools[lastIndex] & _WETH_UNWRAP_MASK > 0

                // last one or only one
                switch unwrapWeth
                case 1 {
                    returnAmount := _makeSwap(
                        address(),
                        payer,
                        refundTo,
                        calldataload(lastPoolStart),
                        amount
                    )
                    _unWrapWeth(receiver, returnAmount)
                }
                case 0 {
                    returnAmount := _makeSwap(
                        receiver,
                        payer,
                        refundTo,
                        calldataload(lastPoolStart),
                        amount
                    )
                }
            }

        }
    }

    /// @inheritdoc IUniswapV3SwapCallback
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) external override {
        assembly {
            // solhint-disable-line no-inline-assembly
            function reRevert() {
                returndatacopy(0, 0, returndatasize())
                revert(0, returndatasize())
            }
            function getBalanceAndTransfer(emptyPtr, token) {
                mstore(emptyPtr, _SELECTORS3)
                mstore(add(8, emptyPtr), address())
                if iszero(
                    staticcall(gas(), token, add(4, emptyPtr), 36, 0, 32)
                ) {
                    reRevert()
                }
                let amount := mload(0)
                if gt(amount, 0) {
                    let refundTo := calldataload(164)
                    mstore(add(4, emptyPtr), refundTo)
                    mstore(add(36, emptyPtr), amount)
                    validateERC20Transfer(
                        call(gas(), token, 0, emptyPtr, 0x44, 0, 0x20)
                    )
                }
            }

            function validateERC20Transfer(status) {
                if iszero(status) {
                    reRevert()
                }
                let success := or(
                    iszero(returndatasize()), // empty return data
                    and(gt(returndatasize(), 31), eq(mload(0), 1)) // true in return data
                )
                if iszero(success) {
                    mstore(
                        0,
                        0xf27f64e400000000000000000000000000000000000000000000000000000000
                    ) // ERC20TransferFailed()
                    revert(0, 4)
                }
            }

            let emptyPtr := mload(0x40)
            let resultPtr := add(emptyPtr, 21) // 0x15 = _FF_FACTORY size

            mstore(emptyPtr, _SELECTORS)
            // token0
            if iszero(staticcall(gas(), caller(), emptyPtr, 4, 0, 32)) {
                reRevert()
            }
            //token1
            if iszero(
                staticcall(gas(), caller(), add(emptyPtr, 4), 4, 32, 32)
            ) {
                reRevert()
            }
            // fee
            if iszero(
                staticcall(gas(), caller(), add(emptyPtr, 8), 4, 64, 32)
            ) {
                reRevert()
            }

            let token
            let amount
            switch sgt(amount0Delta, 0)
            case 1 {
                token := mload(0)
                amount := amount0Delta
            }
            default {
                token := mload(32)
                amount := amount1Delta
            }
            // let salt := keccak256(0, 96)
            mstore(emptyPtr, _FF_FACTORY)
            mstore(resultPtr, keccak256(0, 96)) // Compute the inner hash in-place
            mstore(add(resultPtr, 32), _POOL_INIT_CODE_HASH)
            let pool := and(keccak256(emptyPtr, 85), _ADDRESS_MASK)
            if iszero(eq(pool, caller())) {
                // if xor(pool, caller()) {
                mstore(
                    0,
                    0xb2c0272200000000000000000000000000000000000000000000000000000000
                ) // BadPool()
                revert(0, 4)
            }

            let payer := calldataload(132) // 4+32+32+32+32 = 132
            mstore(emptyPtr, _SELECTORS)
            switch eq(payer, address())
            case 1 {
                // token.safeTransfer(msg.sender,amount)
                mstore(add(emptyPtr, 0x10), caller())
                mstore(add(emptyPtr, 0x30), amount)
                validateERC20Transfer(
                    call(gas(), token, 0, add(emptyPtr, 0x0c), 0x44, 0, 0x20)
                )
                getBalanceAndTransfer(emptyPtr, token)
            }
            default {
                // approveProxy.claimTokens(token, payer, msg.sender, amount);
                mstore(add(emptyPtr, 0x14), token)
                mstore(add(emptyPtr, 0x34), payer)
                mstore(add(emptyPtr, 0x54), caller())
                mstore(add(emptyPtr, 0x74), amount)
                validateERC20Transfer(
                    call(
                        gas(),
                        _APPROVE_PROXY,
                        0,
                        add(emptyPtr, 0x10),
                        0x84,
                        0,
                        0x20
                    )
                )
            }
        }
    }
}
