/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/CommonUtils.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IWNativeRelayer.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IApproveProxy.sol";
import "../interfaces/AbstractCommissionLib.sol";

/// @title Base contract with common payable logics
abstract contract WrapETHSwap is AbstractCommissionLib, CommonUtils {

  uint256 private constant SWAP_AMOUNT = 0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff;

  function swapWrap(uint256 orderId, uint256 rawdata) external payable {
    bool reversed;
    uint128 amount;
    assembly {
      reversed := and(rawdata, _REVERSE_MASK)
      amount := and(rawdata, SWAP_AMOUNT)
    }
    require(amount > 0, "amount must be > 0");

    CommissionInfo memory commissionInfo = _getCommissionInfo();
    
    address srcToken = reversed ? _WETH : _ETH;

    (
        address middleReceiver,
        uint256 balanceBefore
    ) = _doCommissionFromToken(
            commissionInfo,
            srcToken,
            msg.sender,
            msg.sender,
            amount
        );

    if (reversed) {
      IApproveProxy(_APPROVE_PROXY).claimTokens(_WETH, msg.sender, _WNATIVE_RELAY, amount);
      IWNativeRelayer(_WNATIVE_RELAY).withdraw(amount);
      if (middleReceiver != address(this)){
        (bool success, ) = payable(middleReceiver).call{value: address(this).balance}("");
        require(success, "transfer native token failed");
      }
    } else {
      if (!commissionInfo.isFromTokenCommission) {
        require(msg.value == amount, "value not equal amount");
      }
      IWETH(_WETH).deposit{value: amount}();
      if (middleReceiver != address(this)){
        SafeERC20.safeTransfer(IERC20(_WETH), middleReceiver, amount);
      }
    }

    uint256 commissionAmount = _doCommissionToToken(
        commissionInfo,
        address(uint160(msg.sender)),
        balanceBefore
    );

    emit SwapOrderId(orderId);
    emit OrderRecord(reversed ? _WETH : _ETH, reversed ? _ETH: _WETH, tx.origin, amount, amount);
  }
}
