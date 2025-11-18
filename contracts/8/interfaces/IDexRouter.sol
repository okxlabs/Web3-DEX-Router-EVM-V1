// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

import "./IPermit2.sol";

interface IDexRouter {
    struct BaseRequest {
        uint256 fromToken;
        address toToken;
        uint256 fromTokenAmount;
        uint256 minReturnAmount;
        uint256 deadLine;
    }
    struct RouterPath {
        address[] mixAdapters;
        address[] assetTo;
        uint256[] rawData;
        bytes[] extraData;
        uint256 fromToken;
    }
    struct Permit2Info {
        IPermit2.PermitTransferFrom permit;
        address owner;
        bytes signature;
    }
    struct SwapParams {
        address payer;
        address refundTo;
        address receiver;
        address toToken;
    }
    event OrderRecord(
        address fromToken,
        address toToken,
        address sender,
        uint256 fromAmount,
        uint256 returnAmount
    );
    event SwapOrderId(uint256 id);
}