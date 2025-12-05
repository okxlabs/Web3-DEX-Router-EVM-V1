// SPDX-License-Identifier: MIT
pragma solidity >=0.8.17;

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
    event OrderRecord(
        address fromToken,
        address toToken,
        address sender,
        uint256 fromAmount,
        uint256 returnAmount
    );
    event SwapOrderId(uint256 id);
}