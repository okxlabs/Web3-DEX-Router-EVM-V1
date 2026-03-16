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
import "./libraries/WrapETHSwap.sol";
import "./libraries/CommonUtils.sol";
import "./libraries/TempStorage.sol";
import "./storage/PMMRouterStorage.sol";
import "./storage/DexRouterStorage.sol";

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
    WrapETHSwap,
    CommissionLib,
    PMMRouterStorage
{
    string public constant version = "v1.0.4-toB-commission";
    using UniversalERC20 for IERC20;

    struct AfterSwapParams {
        CommissionInfo commissionInfo;
        uint256 consumeAmount;
        uint256 targetTokenBefore;
        address srcToken;
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

        // Step 2: Execute the swap.
        // If srcToken is ETH, the user must prepay ETH; any excess will be refunded after the swap.
        address srcTokenAddress = address(uint160(srcToken & _ADDRESS_MASK));
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
                receiver: receiver,
                payer: payer
            })
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
        // Step 3: Determine the source token for the swap.
        address srcToken;

        if (msg.value > 0) {
            srcToken = _ETH;
        } else {
            address poolAddr = address(uint160(pools[0] & _ADDRESS_MASK));
            bool zeroForOne = (pools[0] & _ONE_FOR_ZERO_MASK) == 0;

            if (zeroForOne) {
                srcToken = IUniV3(poolAddr).token0();
            } else {
                srcToken = IUniV3(poolAddr).token1();
            }
        }

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
        CommissionInfo memory commissionInfo = _getCommissionInfo();
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
                afterSwapParams.srcToken,
                afterSwapParams.payer,
                afterSwapParams.receiver,
                afterSwapParams.consumeAmount
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
            _doCommissionToToken(
                afterSwapParams.commissionInfo,
                afterSwapParams.receiver,
                afterSwapParams.targetTokenBefore
            );
        }
    }
}
