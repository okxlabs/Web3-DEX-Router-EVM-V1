// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/IAspectaKeyPool.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/// @title AspectaAdapter
/// @notice AspectaAdapter is a contract that allows to swap between NativeToken and Key
/// @dev For sellQuote, the fromToken is the key, the key is always keep under the control
/// of the seller address and not transferable, so refund logic is not needed.
contract AspectaAdapter is IAdapter, Ownable {
    uint256 constant ORIGIN_PAYER = 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000; // 0x3ca20afc
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    address constant NATIVE_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WNATIVETOKEN;

    event Received(address sender, uint256 amount);
    // To record swap info for cases that the OrderRecord event is invalid.
    // direction: true for sellBase(buy key), false for sellQuote(sell key)
    event OrderRecord(bool direction, address fromToken, address toToken, uint256 fromAmount, uint256 toAmount);

    constructor(address payable wNativeToken) {
        WNATIVETOKEN = wNativeToken;
    }
    
    struct TradeInfo {
        address fundAddress;
        address tokenAddress;
        bool buyMeme;
        uint256 sellMemeAmount;
        uint256 sellCommissionRate1;
        address sellCommissionReceiver1;
        uint256 sellCommissionRate2;
        address sellCommissionReceiver2;
        uint256 minReturnAmount;
    }

    function _aspectaTrading(
        address to,
        address pool,
        bytes memory moreInfo
    ) private {
        TradeInfo memory tradeInfo = abi.decode(moreInfo, (TradeInfo));
        if (tradeInfo.buyMeme) {
            // Withdraw all wnativeToken to nativeToken
            IWETH(WNATIVETOKEN).withdraw(IWETH(WNATIVETOKEN).balanceOf(address(this)));
            uint256 fromAmount = address(this).balance;
            uint256 toAmountBefore = IAspectaKeyPool(pool).balanceOf(to);


            uint256 protocolFeePercentage = IAspectaKeyPool(pool).getProtocolFeePercentage();
            // protocolFee = (totalPrice * protocolFeePercentage) / 1 ether;
            uint256 amountIn = fromAmount - (fromAmount * protocolFeePercentage) / 1 ether;
            
            (uint256 amountToBuy, uint totalPriceWithFee) = IAspectaKeyPool(pool).getPurchaseAmountByPayment(amountIn);

            _call(pool, abi.encodeWithSelector(IAspectaKeyPool.buyByRouter.selector, amountToBuy, to), totalPriceWithFee);

            address payerOrigin = _getPayerOrigin();
            uint256 refundAmount = address(this).balance;
            if (refundAmount > 0 && payerOrigin != address(0)) {
                IWETH(WNATIVETOKEN).deposit{value: refundAmount}();
                SafeERC20.safeTransfer(IERC20(WNATIVETOKEN), payerOrigin, refundAmount);
            }
            uint256 toAmount = IAspectaKeyPool(pool).balanceOf(to) - toAmountBefore;
            emit OrderRecord(true, NATIVE_ADDRESS, pool, fromAmount, toAmount);
        } else {
            address payerOrigin = _getPayerOrigin();
            require(payerOrigin != address(0), "AspectaAdapter: payerOrigin is zero");
            uint256 toAmountBefore = tx.origin.balance;

            _call(pool, abi.encodeWithSelector(IAspectaKeyPool.sellByRouter.selector, tradeInfo.sellMemeAmount, 0), 0);
            uint256 toAmount = tx.origin.balance - toAmountBefore;
            require(toAmount >= tradeInfo.minReturnAmount, "AspectaAdapter: Min return not reached");
            emit OrderRecord(false, pool, NATIVE_ADDRESS, tradeInfo.sellMemeAmount, toAmount);
        }
    }

    // fromToken == WNativeToken, toToken == Key
    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _aspectaTrading(to, pool, moreInfo);
    }

    // fromToken == Key, toToken == NativeToken and the nativeToken is send to recepient address
    // So actually the aspecta adapter supports the sellQuote toToken commission in DexRouter, but here we keep the same usage as before.
    function sellQuote(
        address, // to
        address pool,
        bytes memory moreInfo
    ) external override {
        _aspectaTrading(address(0), pool, moreInfo);
    }
    
    // call the target contract with value and revert with related string error.
    function _call(address target, bytes memory data, uint256 value) internal {
        (bool success, bytes memory result) = target.call{value: value}(data);
        if (success) {
            return;
        }
        if (result.length < 4) {
            revert("Aspecta: Unknown error");
        }
        bytes4 selector;
        assembly {
            selector := mload(add(result, 32))
        }
        if (selector == 0x6ea6aa1e) {         // TradeNotStarted()
            revert("Aspecta: TradeNotStarted");
        } else if (selector == 0x97d7aeca) {  // MaxKeyHoldExceeded()
            revert("Aspecta: MaxKeyHoldExceeded");
        } else if (selector == 0xd131c780) {  // OpeningPeriodBuyLimitExceeded()
            revert("Aspecta: OpeningPeriodBuyLimitExceeded");
        } else if (selector == 0x03eb8b54) {  // InsufficientFunds(uint256 expected, uint256 received)
            revert("Aspecta: InsufficientFunds");
        } else if (selector == 0xd7d43683) {  // InvalidKeys()
            revert("Aspecta: InvalidKeys");
        } else if (selector == 0x0b310b86) {  // InsufficientKeys()
            revert("Aspecta: InsufficientKeys");
        } else if (selector == 0xc3ac4d7d) {  // MinPriceNotMet(uint256 minPrice, uint256 received)
            revert("Aspecta: MinPriceNotMet");
        } else {
            revert(string(result));
        }
    }

    receive() external payable {
       emit Received(msg.sender, msg.value);
   }

    function _getPayerOrigin() internal pure returns (address payerOriginAddr) {
        uint256 _payerOrigin;
        assembly {
            // Get the total size of the calldata
            let size := calldatasize()
            // Load the last 32 bytes of the calldata, which is assumed to contain the payer origin
            // Assumption: The calldata is structured such that the payer origin is always at the end
            _payerOrigin := calldataload(sub(size, 32))
        }
        if ((_payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            payerOriginAddr = address(uint160(uint256(_payerOrigin) & ADDRESS_MASK));
        }
    }
}