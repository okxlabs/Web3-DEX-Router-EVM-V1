// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Constants.sol";
import "../libraries/EventLib.sol";
import "../libraries/UniswapTokenInfoHelper.sol";
import "../libraries/CommonLib.sol";
import "../libraries/CommissionLib.sol";
import "../libraries/TransferLib.sol";
import "../interfaces/IDexRouter.sol";
import "../interfaces/IERC20.sol";

library UnxswapV3Router {
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

    // ================================================================================
    // ============================== Public Functions ================================
    // ================================================================================
    /// @notice Executes a swap using the Uniswap V3 protocol.
    /// @param receiver The address that will receive the swap funds (encoded as uint256 with order ID mask).
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum acceptable amount of tokens to receive from the swap, guarding against excessive slippage.
    /// @param pools An array of pool identifiers used to define the swap route within Uniswap V3.
    /// @param extraData Additional data encoded in calldata.
    /// @return returnAmount The amount of tokens received after the completion of the swap.
    /// @dev This function wraps and unwraps ETH as required, ensuring the transaction only accepts non-zero `msg.value` for ETH swaps. It invokes `_uniswapV3Swap` to execute the actual swap and handles commission post-swap.
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) public returns (uint256 returnAmount) {
        EventLib.emitSwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        (address srcToken, address toToken) = UniswapTokenInfoHelper.getUniswapV3TokenInfo(msg.value > 0, pools);
        IDexRouter.SwapCache memory swapCache = IDexRouter.SwapCache({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: (receiver & _ADDRESS_MASK) == 0 ? msg.sender : CommonLib.bytes32ToAddress(receiver),
            toToken: toToken
        });
        return
            _uniswapV3SwapTo(
                swapCache,
                srcToken,
                amount,
                minReturn,
                pools,
                extraData
            );
    }

    /// @notice Executes a Uniswap V3 token swap to a specified receiver using structured base request parameters. For uniswapV3, if fromToken or toToken is ETH, the address needs to be 0xEeee.
    /// @param orderId Unique identifier for the swap order, facilitating tracking and reference.
    /// @param receiver The address that will receive the swapped tokens.
    /// @param baseRequest Struct containing essential swap parameters including source token, destination token, amount, minimum return, and deadline.
    /// @param pools An array of pool identifiers defining the Uniswap V3 swap route, with encoded swap direction and unwrap flags.
    /// @param extraData Additional data encoded in calldata.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function validates token compatibility with the provided pool route and ensures proper swap execution.
    /// It supports both ETH and ERC20 token swaps, with automatic WETH wrapping/unwrapping as needed.
    /// The function verifies that fromToken matches the first pool and toToken matches the last pool in the route.
    function uniswapV3SwapToWithBaseRequest(
        uint256 orderId,
        address receiver,
        IDexRouter.BaseRequest calldata baseRequest,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData
    )
        public
        returns (uint256 returnAmount)
    {
        CommonLib.validateDeadline(baseRequest.deadLine);

        EventLib.emitSwapOrderId(orderId);

        (address srcToken, address toToken) = UniswapTokenInfoHelper.getUniswapV3TokenInfo(msg.value > 0, pools);

        // validate fromToken and toToken from baseRequest
        require(
            CommonLib.bytes32ToAddress(baseRequest.fromToken) == srcToken && baseRequest.toToken == toToken,
            "uniswapV3: token mismatch"
        );

        IDexRouter.SwapCache memory swapCache = IDexRouter.SwapCache({
            payer: msg.sender,
            refundTo: msg.sender,
            receiver: receiver == address(0) ? msg.sender : receiver,
            toToken: toToken
        });
        return
            _uniswapV3SwapTo(
                swapCache,
                srcToken,
                baseRequest.fromTokenAmount,
                baseRequest.minReturnAmount,
                pools,
                extraData
            );
    }

    /// @notice Callback function invoked by Uniswap V3 pools during a swap.
    /// @param amount0Delta The change in token0 balance (positive means the contract must pay token0).
    /// @param amount1Delta The change in token1 balance (positive means the contract must pay token1).
    /// @dev This function is called by the Uniswap V3 pool after executing a swap. It handles the payment of tokens to the pool.
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata /*data*/
    ) public {
        _uniswapV3SwapCallback(amount0Delta, amount1Delta);
    }


    // ================================================================================
    // ============================== Private Functions ===============================
    // ================================================================================
    /// @notice If srcToken or toToken is ETH, the address needs to be 0xEeee. And for commission validation, ETH needs to be 0xEeee.
    function _uniswapV3SwapTo(
        IDexRouter.SwapCache memory swapCache,
        address srcToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData
    ) private returns (uint256 returnAmount) {
        uint256 mode = pools[0] & _TRANSFER_MODE_MASK;

        if (mode == _MODE_BY_INVEST) {
            swapCache.refundTo = extraData.refundTo;
        }

        CommissionLib.validateCommissionInfo(extraData.commissionInfo, srcToken, swapCache.toToken, mode);
        extraData.commissionInfo.tokenWithMode = mode | extraData.commissionInfo.tokenWithMode;

        returnAmount = CommonLib.getBalanceOf(swapCache.toToken, swapCache.receiver);

        uint256 fromTokenCommissionAmount;
        (
            swapCache.payer,
            amount,
            fromTokenCommissionAmount
        ) = TransferLib.handlePermit2SigModeWithCommission(
            uint256(uint160(srcToken)) | mode,
            swapCache.payer,
            amount,
            address(0),
            extraData
        );

        _doUniswapV3Swap(
            swapCache,
            amount,
            pools,
            extraData,
            fromTokenCommissionAmount
        );

        // check minReturnAmount
        returnAmount = CommonLib.getBalanceOf(swapCache.toToken, swapCache.receiver) - returnAmount;
        require(
            returnAmount >= minReturn,
            "Min return not reached"
        );

        // Refund unused fromToken
        if (srcToken == _ETH) {
            TransferLib.refundToken(_ETH, swapCache.refundTo); // In case of  msg.value > amount, the unused ETH will be refunded to refundTo
        }

        EventLib.emitOrderRecord(
            srcToken,
            swapCache.toToken,
            tx.origin,
            amount,
            returnAmount
        );
    }

    function _doUniswapV3Swap(
        IDexRouter.SwapCache memory swapCache,
        uint256 amount,
        uint256[] calldata pools,
        IDexRouter.ExtraData memory extraData,
        uint256 fromTokenCommissionAmount
    ) private {
        
        (
            address middleReceiver,
            uint256 balanceBefore
        ) = CommissionLib.doCommissionFromToken(
                extraData.commissionInfo,
                swapCache,
                fromTokenCommissionAmount,
                extraData.trimInfo.hasTrim
            );

        _uniswapV3Swap(
            swapCache.payer,
            payable(middleReceiver),
            amount,
            pools
        );

        CommissionLib.doCommissionAndTrimToToken(
            extraData.commissionInfo,
            swapCache.receiver,
            balanceBefore,
            swapCache.toToken,
            extraData.trimInfo
        );
    }

    /// @notice Conducts a swap using the Uniswap V3 protocol internally within the contract.
    /// @param payer The address of the account providing the tokens for the swap.
    /// @param receiver The address that will receive the tokens after the swap.
    /// @param amount The amount of the source token to be swapped.
    /// @param pools An array of pool identifiers defining the swap route within Uniswap V3.
    /// @return returnAmount The amount of tokens received from the swap.
    /// @dev This internal function encapsulates the core logic for executing swaps on Uniswap V3. It is intended to be used by other functions in the contract that prepare and pass the necessary parameters. The function handles the swapping process, ensuring that the minimum return is met and managing the transfer of tokens.
    function _uniswapV3Swap(
        address payer,
        address payable receiver,
        uint256 amount,
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
            function _makeSwap(_receiver, _payer, _refundTo, _pool, _amount, _transferMode)
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
                    mstore(add(paramPtr, 0xa0), 128)                    // data.length = 128 (0x80)
                    mstore(add(paramPtr, 0xc0), V3_EXACT_IN_CALLBACK_FLAG)  // data[0] = flag
                    mstore(add(paramPtr, 0xe0), _payer)                 // data[1] = payer
                    mstore(add(paramPtr, 0x100), _refundTo)             // data[2] = refundTo
                    mstore(add(paramPtr, 0x120), _transferMode)         // data[3] = transferMode
                    let success := call(
                        gas(),
                        poolAddr,
                        0,
                        freePtr,
                        0x144,
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
                    mstore(add(paramPtr, 0xa0), 128)                    // data.length = 128 (0x80)
                    mstore(add(paramPtr, 0xc0), V3_EXACT_IN_CALLBACK_FLAG)  // data[0] = flag
                    mstore(add(paramPtr, 0xe0), _payer)                 // data[1] = payer
                    mstore(add(paramPtr, 0x100), _refundTo)             // data[2] = refundTo
                    mstore(add(paramPtr, 0x120), _transferMode)         // data[3] = transferMode
                    let success := call(
                        gas(),
                        poolAddr,
                        0,
                        freePtr,
                        0x144,
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

                // withdraw WETH to ETH
                mstore(freePtr, _SELECTORS2) // withdraw(uint256) selector (first 4 bytes)
                mstore(add(freePtr, 4), _amount)
                let success := call(gas(), _WETH, 0, freePtr, 36, 0, 0)
                if iszero(success) {
                    _revertWithReason(
                        0x0000001477697468647261772077657468206661696c65640000000000000000,
                        88
                    ) // withdraw weth failed
                }
                // send ETH to receiver
                success := call(NATIVE_TOKEN_TRANSFER_GAS_LIMIT, _receiver, _amount, 0, 0, 0, 0)
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
                    amount,
                    and(calldataload(firstPoolStart), _TRANSFER_MODE_MASK)
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
                        amount,
                        and(calldataload(lastPoolStart), _TRANSFER_MODE_MASK)
                    )
                    _unWrapWeth(receiver, returnAmount)
                }
                case 0 {
                    returnAmount := _makeSwap(
                        receiver,
                        payer,
                        refundTo,
                        calldataload(lastPoolStart),
                        amount,
                        and(calldataload(lastPoolStart), _TRANSFER_MODE_MASK)
                    )
                }
            }

        }
    }

    function _uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta
    ) private {
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
                    let refundTo := calldataload(196) // offset adjusted for flag: 164 + 32 = 196
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
                        0x0000001b7472616e7366657220746f6b656e2072656665726572206661696c00,
                        0x5f
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
                        0x0000001b7472616e7366657220746f6b656e2072656665726572206661696c00,
                        0x5f
                    ) // "transfer token referer fail"
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
                    ) // "claim tokens failed"
                }
            }
            
            function _transferTokenWithMode(token, mode, _payer, to, amount) {
                if gt(amount, 0) {
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
                            0x00000015696e76616c6964207472616e73666572206d6f646500000000000000,
                            0x59
                        ) // "invalid transfer mode"
                    }
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

            // Calldata layout after adding flag:
            // offset 132: data[0] = flag (32 bytes) - skipped by DexRouter
            // offset 164: data[1] = payer (32 bytes)
            // offset 196: data[2] = refundTo (32 bytes)
            // offset 228: data[3] = transferMode (32 bytes)
            let payer := calldataload(164)        // 132 + 32 = 164 (skip flag)
            let transferMode := calldataload(228) // 164 + 64 = 228
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
                // payer is not address(this), use transferMode
                _transferTokenWithMode(token, transferMode, payer, caller(), amount)
            }
        }
    }
}