// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./libraries/ECDSA.sol";

library OrderRFQLib {
    struct OrderRFQ {
        uint256 rfqId; // 0x00
        uint256 expiry; // 0x20
        address makerAsset; // 0x40
        address takerAsset; // 0x60
        address makerAddress; // 0x80
        uint256 makerAmount; // 0xa0
        uint256 takerAmount; // 0xc0
        bool usePermit2; // 0xe0
        address allowedSender; // 0x100
        uint256 confidenceT; // 0x120
        uint256 confidenceWeight; // 0x140
        uint256 confidenceCap; // 0x160
        bytes permit2Signature;
        bytes32 permit2Witness;
        string permit2WitnessType;
    }
    // forgefmt: disable-start
    bytes32 internal constant _LIMIT_ORDER_RFQ_TYPEHASH =
        keccak256(
            "OrderRFQ("
            "uint256 rfqId,"
            "uint256 expiry,"
            "address makerAsset,"
            "address takerAsset,"
            "address makerAddress,"
            "uint256 makerAmount,"
            "uint256 takerAmount,"
            "bool usePermit2,"
            "address allowedSender,"
            "uint256 confidenceT,"
            "uint256 confidenceWeight,"
            "uint256 confidenceCap,"
            "bytes permit2Signature,"
            "bytes32 permit2Witness,"
            "string permit2WitnessType"
            ")"
        );
    // forgefmt: disable-end

    function hash(OrderRFQ memory order, bytes32 domainSeparator) internal pure returns (bytes32 result) {
        // Manually encoding each field instead of abi.encode(..., order)
        // to avoid Yul "stack too deep" errors caused by expanding memory structs.
        bytes32 structHash = keccak256(
            abi.encode(
                _LIMIT_ORDER_RFQ_TYPEHASH,
                order.rfqId,
                order.expiry,
                order.makerAsset,
                order.takerAsset,
                order.makerAddress,
                order.makerAmount,
                order.takerAmount,
                order.usePermit2,
                order.allowedSender,
                order.confidenceT,
                order.confidenceWeight,
                order.confidenceCap,
                keccak256(order.permit2Signature),
                order.permit2Witness,
                keccak256(bytes(order.permit2WitnessType))
            )
        );
        return ECDSA.toTypedDataHash(domainSeparator, structHash);
    }
}
