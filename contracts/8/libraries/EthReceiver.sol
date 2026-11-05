/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Base contract with common payable logics
abstract contract EthReceiver {
  receive() external payable {
    // solhint-disable-next-line avoid-tx-origin
    require(msg.sender != tx.origin, "ETH deposit rejected");
  }
}
