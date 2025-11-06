// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./UnxswapExactOutRouter.sol";
import "./UnxswapV3ExactOutRouter.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/IAdapter.sol";
import "./interfaces/IApproveProxy.sol";
import "./interfaces/IWNativeRelayer.sol";
import "./interfaces/IXBridge.sol";

import "./libraries/Permitable.sol";
import "./libraries/PMMLib.sol";
import "./libraries/CommissionLib.sol";
import "./libraries/EthReceiver.sol";
import "./libraries/CommonUtils.sol";
import "./libraries/TempStorage.sol";
import "./storage/PMMRouterStorage.sol";
import "./storage/DexRouterStorage.sol";
import "./libraries/UniswapTokenInfoHelper.sol";

/// @title DexRouterExactOut
/// @notice Entrance of Split trading in Dex platform, must be inherited from UnxswapExactOutRouter and UnxswapV3ExactOutRouter
/// @dev Entrance of Split trading in Dex platform
contract DexRouterExactOut is
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    Permitable,
    EthReceiver,
    UnxswapExactOutRouter,
    UnxswapV3ExactOutRouter,
    DexRouterStorage,
    CommissionLib,
    PMMRouterStorage,
    UniswapTokenInfoHelper
{
    string public constant version = "v1.0.5-tee";
    using UniversalERC20 for IERC20;

    struct AfterSwapParams {
        CommissionInfo commissionInfo;
        uint256 consumeAmount;
        uint256 targetTokenBefore;
        address srcToken;
        address toToken;
        address receiver;
        address payer;
    }

    /// @notice Initializes the contract with necessary setup for ownership and reentrancy protection.
    /// @dev This function serves as a constructor for upgradeable contracts and should be called
    /// through a proxy during the initial deployment. It initializes inherited contracts
    /// such as `OwnableUpgradeable` and `ReentrancyGuardUpgradeable` to set up the contract's owner
    /// and reentrancy guard.
    function initialize() public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    //-------------------------------
    //------- Events ----------------
    //-------------------------------

    /// @notice Emitted when a priority address status is updated.
    /// @param priorityAddress The address whose priority status has been changed.
    /// @param valid A boolean indicating the new status of the priority address.
    /// True means the address is now considered a priority address, and false means it is not.
    event PriorityAddressChanged(address priorityAddress, bool valid);

    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling.
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param amount The target output amount to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param receiver The address to receive the output tokens.
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function unxswapExactOutTo(
        uint256 srcToken,
        uint256 amount,
        uint256 maxConsume,
        address receiver,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable whenNotPaused returns (uint256 consumeAmount) {
        emit SwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        return
            _unxswapExactOutTo(
                srcToken,
                amount,
                maxConsume,
                msg.sender,
                receiver,
                pools
            );
    }

    /// @notice Executes an exact output swap using the Unxswap protocol, including commission handling. The receiver is set to msg.sender.
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param amount The target output amount to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function unxswapExactOutToByOrderID(
        uint256 srcToken,
        uint256 amount,
        uint256 maxConsume,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable whenNotPaused returns (uint256 consumeAmount) {
        emit SwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        return
            _unxswapExactOutTo(
                srcToken,
                amount,
                maxConsume,
                msg.sender,
                msg.sender,
                pools
            );
    }

    /// @notice Internal function to perform an exact output swap using the Unxswap protocol, handling commission logic for both source and target tokens.
    /// @notice ETH address on this parameter srcToken is 0x0000000000000000000000000000000000000000
    /// @param srcToken The source token as a uint256 (address encoded with order ID mask).
    /// @param amount The target output amount to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param payer The address paying the source tokens.
    /// @param receiver The address to receive the output tokens.
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed, including commission.
    function _unxswapExactOutTo(
        uint256 srcToken,
        uint256 amount,
        uint256 maxConsume,
        address payer,
        address receiver,
        bytes32[] calldata pools
    ) internal returns (uint256 consumeAmount) {
        require(receiver != address(0), "not addr(0)");
        // Step 1: Adjust the target output amount to include commission if commission is taken from the output token.
        uint256 targetTokenBefore = 0;
        address middleReceiver = receiver;
        CommissionInfo memory commissionInfo;
        (
            commissionInfo,
            amount,
            targetTokenBefore,
            middleReceiver
        ) = _beforeSwap(amount, middleReceiver, targetTokenBefore);

        // Step 2: Validate and execute the swap.
        // If srcToken is ETH, the user must prepay ETH; any excess will be refunded after the swap.
        address srcTokenAddress = address(uint160(srcToken & _ADDRESS_MASK));
        address toToken = _validateUnxswapToken(srcTokenAddress, pools);
        consumeAmount = _unxswapExactOutInternal(
            IERC20(srcTokenAddress),
            amount,
            maxConsume,
            pools,
            payer,
            middleReceiver
        );

        // Step 3: Handle commission from the source token if applicable.
        _afterSwap(
            AfterSwapParams({
                commissionInfo: commissionInfo,
                consumeAmount: consumeAmount,
                targetTokenBefore: targetTokenBefore,
                srcToken: srcTokenAddress == address(0) ? _ETH : srcTokenAddress,
                toToken: toToken,
                receiver: receiver,
                payer: payer
            })
        );
    }

    /// @notice For unxswap, if srcToken is ETH, srcToken needs to be address(0).
    function _validateUnxswapToken(
        address srcTokenAddress,
        bytes32[] calldata pools
    ) internal view returns (address toToken) {
        address fromToken;
        (fromToken, toToken) = _getUnxswapTokenInfo(msg.value > 0, pools);
        require(
            (srcTokenAddress == fromToken && fromToken != _ETH) || (srcTokenAddress == address(0) && fromToken == _ETH),
            "unxswap: token mismatch"
        );
    }

    /// @notice Executes an exact output swap using the Uniswap V3 protocol, including commission handling.
    /// @param receiver The address to receive the output tokens (encoded as uint256).
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed.
    function uniswapV3SwapExactOutTo(
        uint256 receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256[] calldata pools
    ) external payable whenNotPaused returns (uint256 consumeAmount) {
        emit SwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        consumeAmount = _uniswapV3SwapExactOutTo(
            msg.sender,
            receiver,
            amountOut,
            maxConsume,
            pools
        );
    }

    /// @notice Internal function to perform an exact output swap using the Uniswap V3 protocol, handling commission logic for both source and target tokens.
    /// @param payer The address paying the source tokens.
    /// @param receiver The address to receive the output tokens (encoded as uint256).
    /// @param amountOut The exact amount of output tokens to receive.
    /// @param maxConsume The maximum amount of source tokens to consume (slippage protection).
    /// @param pools The list of pool identifiers to use for the swap path.
    /// @return consumeAmount The actual amount of source tokens consumed.
    function _uniswapV3SwapExactOutTo(
        address payer,
        uint256 receiver,
        uint256 amountOut,
        uint256 maxConsume,
        uint256[] calldata pools
    ) internal returns (uint256 consumeAmount) {
        require(address(uint160(receiver)) != address(0), "not addr(0)");
        // Step 1: If the swap starts from ETH, the contract will wrap ETH to WETH in the last pool.
        TempStorage.setEthAmount(msg.value);
        // Step 2: Adjust the target output amount to include commission if commission is taken from the output token.
        uint256 targetTokenBefore = 0;
        address middleReceiver = address(uint160(receiver));
        CommissionInfo memory commissionInfo;
        (
            commissionInfo,
            amountOut,
            targetTokenBefore,
            middleReceiver
        ) = _beforeSwap(amountOut, middleReceiver, targetTokenBefore);
        // Step 3: Determine the source token and to token for the swap.
        (address srcToken, address toToken) = _getUniswapV3TokenInfo(msg.value > 0, pools);

        // Step 4: Execute the swap. If srcToken is ETH, any excess ETH will be refunded after the swap.
        consumeAmount = _uniswapV3SwapExactOut(
            payer,
            payable(middleReceiver),
            amountOut,
            maxConsume,
            pools
        );

        // Step 5: Handle commission from the source token if applicable.
        _afterSwap(
            AfterSwapParams({
                commissionInfo: commissionInfo,
                consumeAmount: consumeAmount,
                targetTokenBefore: targetTokenBefore,
                srcToken: srcToken,
                toToken: toToken,
                receiver: address(uint160(receiver)),
                payer: payer
            })
        );

        // Step 6: Reset ethAmount to zero after the swap.
        TempStorage.setEthAmount(0);
    }

    // Adjusts the target output amount to include commission if commission is taken from the output token.
    function _beforeSwap(
        uint256 amountOut,
        address middleReceiver,
        uint256 targetTokenBefore
    ) internal returns (CommissionInfo memory, uint256, uint256, address) {
        (CommissionInfo memory commissionInfo, ) = _getCommissionAndTrimInfo();
        if (
            commissionInfo.isToTokenCommission &&
            commissionInfo.commissionRate > 0
        ) {
            uint256 totalRate = commissionInfo.commissionRate +
                commissionInfo.commissionRate2;
            // DENOMINATOR is defined in the CommissionLib.sol
            amountOut = (amountOut * DENOMINATOR) / (DENOMINATOR - totalRate);
            targetTokenBefore = _getBalanceOf(
                /// @notice commissionInfo.token ETH address is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                commissionInfo.token,
                address(this)
            );
            middleReceiver = address(this);
        }
        return (commissionInfo, amountOut, targetTokenBefore, middleReceiver);
    }

    // Handles commission.
    function _afterSwap(AfterSwapParams memory afterSwapParams) internal {
        // validate commission info
        _validateCommissionInfo(afterSwapParams.commissionInfo, afterSwapParams.srcToken, afterSwapParams.toToken, _MODE_LEGACY); // @notice For commission validation, ETH needs to be 0xEeee.

        // Handle commission from the source token if applicable.
        if (
            afterSwapParams.commissionInfo.isFromTokenCommission &&
            afterSwapParams.commissionInfo.commissionRate > 0
        ) {
            uint256 commissionAmount = 0;
            // Calculate the commission amount by checking the contract's balance before and after commission transfer.
            if (
                afterSwapParams.srcToken == _ETH &&
                msg.value > afterSwapParams.consumeAmount
            ) {
                commissionAmount = _getBalanceOf(
                    /// @notice commissionInfo.token ETH address is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
                    afterSwapParams.commissionInfo.token,
                    address(this)
                );
            }
            _doCommissionFromToken(
                afterSwapParams.commissionInfo,
                afterSwapParams.payer,
                afterSwapParams.receiver,
                afterSwapParams.consumeAmount,
                false,
                afterSwapParams.toToken
            );
            if (
                afterSwapParams.srcToken == _ETH &&
                msg.value > afterSwapParams.consumeAmount
            ) {
                commissionAmount =
                    commissionAmount -
                    _getBalanceOf(
                        afterSwapParams.commissionInfo.token,
                        address(this)
                    );
            }
            // Add the commission to the total consumed amount.
            afterSwapParams.consumeAmount += commissionAmount;
        }

        // Refund any excess ETH to the payer if the source token is ETH.
        if (
            afterSwapParams.srcToken == _ETH &&
            msg.value > afterSwapParams.consumeAmount
        ) {
            payable(afterSwapParams.payer).transfer(
                msg.value - afterSwapParams.consumeAmount
            );
        }

        // Handle commission from the output token if applicable.
        if (
            afterSwapParams.commissionInfo.isToTokenCommission &&
            afterSwapParams.commissionInfo.commissionRate > 0
        ) {
            TrimInfo memory trimInfo;
            _doCommissionAndTrimToToken(
                afterSwapParams.commissionInfo,
                afterSwapParams.receiver,
                afterSwapParams.targetTokenBefore,
                afterSwapParams.toToken,
                trimInfo
            );
        }
    }
}