/// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

library RouterErrors {
    error ReturnAmountIsNotEnough();
    error InvalidMsgValue();
    error ERC20TransferFailed();
    error EmptyPools();
    error InvalidFromToken();
    error MsgValuedNotRequired();
}