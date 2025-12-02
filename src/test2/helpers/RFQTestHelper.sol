// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@dex/interfaces/IPermit2.sol";

library ECDSA {
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 res) {
        // return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        /// @solidity memory-safe-assembly
        assembly {
            // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)
            mstore(ptr, 0x1901000000000000000000000000000000000000000000000000000000000000) // "\x19\x01"
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            res := keccak256(ptr, 66)
        }
    }
}

library OrderRFQLib {
    struct OrderRFQ {
        uint256 rfqId; // 0x00
        uint256 expiry; // 0x20
        address makerAsset; // 0x40
        address takerAsset; // 0x60
        address makerAddress; // 0x80
        uint256 makerAmount; // 0xa0
        uint256 takerAmount; // 0xc0
        bool usePermit2; // 0xe0;
        bytes permit2Signature; // 0xf0;
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
                keccak256(order.permit2Signature),
                order.permit2Witness,
                keccak256(bytes(order.permit2WitnessType))
            )
        );
        return ECDSA.toTypedDataHash(domainSeparator, structHash);
    }
}

contract TestHelper is Test {
    using OrderRFQLib for OrderRFQLib.OrderRFQ;

    // Test private keys (these are test keys, never use in production)
    uint256 public constant MAKER_PRIVATE_KEY = uint256(keccak256("maker-test-seed"));
    uint256 public constant TAKER_PRIVATE_KEY = uint256(keccak256("taker-test-seed"));

    bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    // Generate addresses from private keys
    address public immutable MAKER_ADDRESS;
    address public immutable TAKER_ADDRESS;

    constructor() {
        MAKER_ADDRESS = vm.addr(MAKER_PRIVATE_KEY);
        TAKER_ADDRESS = vm.addr(TAKER_PRIVATE_KEY);
    }

    function createOrder(
        uint256 rfqId,
        uint256 expiry,
        address makerAsset,
        address takerAsset,
        address makerAddress,
        uint256 makerAmount,
        uint256 takerAmount,
        bool usePermit2
    ) internal pure returns (OrderRFQLib.OrderRFQ memory) {
        return OrderRFQLib.OrderRFQ({
            rfqId: rfqId,
            expiry: expiry,
            makerAsset: makerAsset,
            takerAsset: takerAsset,
            makerAddress: makerAddress,
            makerAmount: makerAmount,
            takerAmount: takerAmount,
            usePermit2: usePermit2,
            permit2Signature: "",
            permit2Witness: bytes32(0),
            permit2WitnessType: ""
        });
    }

    function signOrder(OrderRFQLib.OrderRFQ memory order, bytes32 domainSeparator, uint256 privateKey)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 orderHash = order.hash(domainSeparator);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, orderHash);
        return abi.encodePacked(r, s, v);
    }

    function getPermit2Signature(
        IPermit2.PermitTransferFrom memory permit,
        address pmmProtocolAddress,
        uint256 privateKey,
        bytes32 domainSeparator
    ) internal pure returns (bytes memory sig) {
        bytes32 tokenPermissions = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_FROM_TYPEHASH,
                        tokenPermissions,
                        pmmProtocolAddress,
                        permit.nonce,
                        permit.deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);
        return bytes.concat(r, s, bytes1(v));
    }

    function getFutureTimestamp(uint256 offset) internal view returns (uint256) {
        return block.timestamp + offset;
    }

    function getCurrentTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}
