// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

interface IPMMProtocol {
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
    function fillOrderRFQTo(
        OrderRFQ memory order,
        bytes calldata signature,
        uint256 flagsAndAmount,
        address target
    ) external returns (uint256, uint256, bytes32);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract PMMAdapter {
    using Strings for uint256;
    uint256 internal constant ORIGIN_PAYER =
        0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    enum SignatureType {
        EIP712,
        EIP1271
    }
    constructor() {}

    function _PMMSwap(
        address to,
        address pool,
        bytes memory moreInfo,
        uint256 payerOrigin
    ) internal {
        (
            IPMMProtocol.OrderRFQ memory order,
            bytes memory signature,
            uint256 signatureType
        ) = abi.decode(moreInfo, (IPMMProtocol.OrderRFQ, bytes, uint256));
        uint256 amount = IERC20(order.takerAsset).balanceOf(address(this));
        if (amount > order.takerAmount) {
            // The surplus will be returned back to the payer in the end
            amount = order.takerAmount;
        }
        require(amount > 0, "Zero balance of PMM adapter");
        SafeERC20.safeApprove(IERC20(order.takerAsset), pool, amount);
        uint256 flagsAndAmount = (
            signatureType == uint256(SignatureType.EIP1271) ? 1 << 254 : 0
        ) + amount;

        // IPMMProtocol(pool).fillOrderRFQTo(order, signature, flagsAndAmount, to);
        _call(
            pool,
            abi.encodeWithSelector(
                IPMMProtocol.fillOrderRFQTo.selector,
                order,
                signature,
                flagsAndAmount,
                to
            ),
            order.rfqId
        );

        address _payerOrigin;
        if ((payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            _payerOrigin = address(uint160(uint256(payerOrigin) & ADDRESS_MASK));
        }
        uint256 amountLeft = IERC20(order.takerAsset).balanceOf(address(this));
        if (amountLeft > 0 && _payerOrigin != address(0)) {
            SafeERC20.safeTransfer(
                IERC20(order.takerAsset),
                _payerOrigin,
                amountLeft
            );
        }
    }

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _PMMSwap(to, pool, moreInfo, payerOrigin);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _PMMSwap(to, pool, moreInfo, payerOrigin);
    }

    function _call(address target, bytes memory data, uint256 rfqId) internal {
        (bool success, bytes memory result) = target.call(data);
        if (success) {
            return;
        }
        if (result.length < 4) {
            // revert("RFQ: Unknown error");
            revert(
                string(
                    abi.encodePacked("RFQ: Unknown error ", rfqId.toString())
                )
            );
        }
        bytes4 selector;
        assembly {
            selector := mload(add(result, 0x20))
        }

        // All cases tested
        if (selector == 0x7d0bdf81) {
            // RFQ_InvalidMsgValue(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_InvalidMsgValue ", rfqId.toString())
                )
            );
        } else if (selector == 0x1952c5f3) {
            // RFQ_ETHTransferFailed(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_ETHTransferFailed ", rfqId.toString())
                )
            );
        } else if (selector == 0x8fde5c60) {
            // RFQ_ZeroTargetIsForbidden(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_ZeroTargetIsForbidden ", rfqId.toString())
                )
            );
        } else if (selector == 0x87a26f41) {
            // RFQ_BadSignature(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_BadSignature ", rfqId.toString())
                )
            );
        } else if (selector == 0x84935d57) {
            // RFQ_OrderExpired(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_OrderExpired ", rfqId.toString())
                )
            );
        } else if (selector == 0x48872c38) {
            // RFQ_MakerAmountExceeded(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_MakerAmountExceeded ", rfqId.toString())
                )
            );
        } else if (selector == 0x51c6158e) {
            // RFQ_TakerAmountExceeded(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_TakerAmountExceeded ", rfqId.toString())
                )
            );
        } else if (selector == 0x94d42471) {
            // RFQ_SwapWithZeroAmount(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_SwapWithZeroAmount ", rfqId.toString())
                )
            );
        } else if (selector == 0x6fe432b3) {
            // RFQ_InvalidatedOrder(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_InvalidatedOrder ", rfqId.toString())
                )
            );
        } else if (selector == 0xf4a08977) {
            // RFQ_EthDepositRejected()
            // Won't be triggerred here unless `data` is empty
            revert("RFQ_EthDepositRejected");
        } else if (selector == 0xf4059071) {
            // SafeTransferFromFailed()
            revert(
                string(
                    abi.encodePacked("RFQ_SafeTransferFromFailed ", rfqId.toString())
                )
            );
        } else if (selector == 0x8112e119) {
            // Permit2TransferAmountTooHigh()
            revert(
                string(
                    abi.encodePacked("RFQ_Permit2TransferAmountTooHigh ", rfqId.toString())
                )
            );
        } else if (selector == 0xfb7f5079) {
            // SafeTransferFailed()
            revert(
                string(
                    abi.encodePacked("RFQ_SafeTransferFailed ", rfqId.toString())
                )
            );
        } else if (selector == 0x19be9a90) {
            // ForceApproveFailed()
            revert(
                string(
                    abi.encodePacked("RFQ_ForceApproveFailed ", rfqId.toString())
                )
            );
        } else if (selector == 0x8216cd1c) {
            // SafeIncreaseAllowanceFailed()
            revert(
                string(
                    abi.encodePacked("RFQ_SafeIncreaseAllowanceFailed ", rfqId.toString())
                )
            );
        } else if (selector == 0x840bdf26) {
            // SafeDecreaseAllowanceFailed()
            revert(
                string(
                    abi.encodePacked("RFQ_SafeDecreaseAllowanceFailed ", rfqId.toString())
                )
            );
        } else if (selector == 0x68275857) {
            // SafePermitBadLength()
            revert(
                string(
                    abi.encodePacked("RFQ_SafePermitBadLength ", rfqId.toString())
                )
            );
        } else if (selector == 0xc6f643b2) {
            // RFQ_AmountTooLarge(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_AmountTooLarge ", rfqId.toString())
                )
            );
        } else if (selector == 0xa1475d7b) {
            // RFQ_SettlementAmountTooSmall(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_SettlementAmountTooSmall ", rfqId.toString())
                )
            );
        } else if (selector == 0x589584f5) {
            // RFQ_OrderAlreadyCancelledOrUsed(uint256 rfqId);
            revert(
                string(
                    abi.encodePacked("RFQ_OrderAlreadyCancelledOrUsed ", rfqId.toString())
                )
            );
        } else {
            revert(
                string(
                    abi.encodePacked("RFQ_Failed ", rfqId.toString())
                )
            );
        }
    }
}