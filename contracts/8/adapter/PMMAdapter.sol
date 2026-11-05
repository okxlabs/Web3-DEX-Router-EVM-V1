// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {OrderRFQLib} from "./pmm/OrderRFQLib.sol";
import {CallerAuth} from "./pmm/libraries/CallerAuth.sol";
import {Errors} from "./pmm/libraries/Errors.sol";
import {ORIGIN_PAYER, MARKER_MASK, _ADDRESS_MASK} from "./pmm/libraries/Constants.sol";

struct CallerAuthData {
    address[] allowedCallers;
    uint256 nonce;
    bytes authSig;
}

interface IPMMProtocolV1 {
    struct OrderRFQ {
        uint256 rfqId;
        uint256 expiry;
        address makerAsset;
        address takerAsset;
        address makerAddress;
        uint256 makerAmount;
        uint256 takerAmount;
        bool usePermit2;
    }

    function fillOrderRFQTo(OrderRFQ memory order, bytes calldata signature, uint256 flagsAndAmount, address target)
        external
        returns (uint256, uint256, bytes32);
}

interface IPMMProtocolV2 {
    struct OrderRFQ {
        uint256 rfqId;
        uint256 expiry;
        address makerAsset;
        address takerAsset;
        address makerAddress;
        uint256 makerAmount;
        uint256 takerAmount;
        bool usePermit2;
        bytes permit2Signature;
        bytes32 permit2Witness;
        string permit2WitnessType;
    }

    function fillOrderRFQTo(OrderRFQ memory order, bytes calldata signature, uint256 flagsAndAmount, address target)
        external
        returns (uint256, uint256, bytes32);
}

interface IPMMProtocolV3 {
    struct OrderRFQ {
        uint256 rfqId; // 0x00
        uint256 expiry; // 0x20
        address makerAsset; // 0x40
        address takerAsset; // 0x60
        address makerAddress; // 0x80
        uint256 makerAmount; // 0xa0
        uint256 takerAmount; // 0xc0
        bool usePermit2; // 0xe0
        uint256 confidenceT; // 0x100
        uint256 confidenceWeight; // 0x120
        uint256 confidenceCap; // 0x140
        bytes permit2Signature;
        bytes32 permit2Witness;
        string permit2WitnessType;
    }

    function fillOrderRFQTo(OrderRFQ memory order, bytes calldata signature, uint256 flagsAndAmount, address target)
        external
        returns (uint256, uint256, bytes32);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

interface IPMMProtocolV4 {
    function fillOrderRFQTo(
        OrderRFQLib.OrderRFQ memory order,
        bytes calldata signature,
        uint256 flagsAndAmount,
        address target,
        address[] calldata allowedCallers,
        uint256 nonce,
        bytes calldata authSig
    ) external returns (uint256, uint256, bytes32);
}

contract PMMAdapter is CallerAuth, ReentrancyGuard {
    using Strings for uint256;

    // Protocol-level hard cap on confidence (time-slippage) cutdown, mirrors
    // PmmProtocol.sol `_CONFIDENCE_CAP_LIMIT` (5% in 1e6 units). Used only by the
    // read-only maker-balance fallback check; see _getMakerAmountForBalanceCheck.
    uint256 private constant _CONFIDENCE_CAP_LIMIT = 50000;

    enum SignatureType {
        EIP712,
        EIP1271
    }

    /// @dev In-memory context for the read-only maker-balance recheck performed in the
    /// `_call` fallback (else) branch. Populated only for V2/V3 Permit2 paths;
    /// when `enabled == false` the 4-arg `_call` behaves identically to the legacy 3-arg one.
    struct MakerBalanceCheck {
        bool enabled; // true only for Permit2-signature V2/V3 orders
        address makerAsset; // order.makerAsset — token whose balanceOf(maker) is queried
        address maker; // order.makerAddress — account whose balance is checked
        uint256 makerAmount; // maker payout for the fill (stage-1 threshold)
        uint256 confidenceT; // order.confidenceT      ┐ V3 time-slippage inputs
        uint256 confidenceWeight; // order.confidenceWeight ├ (V2 fills these with 0 → disabled)
        uint256 confidenceCap; // order.confidenceCap    ┘
    }

    constructor(address authSigner) CallerAuth(authSigner) {}

    function _PMMSwap(address to, address pool, bytes memory moreInfo, uint256 payerOrigin) internal {
        (bytes memory orderInfo, bytes memory signature, uint256 signatureType, uint256 orderType) =
            abi.decode(moreInfo, (bytes, bytes, uint256, uint256));

        if (orderType == 1) {
            _executeV1Order(to, pool, orderInfo, signature, signatureType, payerOrigin);
        } else if (orderType == 2) {
            _executeV2Order(to, pool, orderInfo, signature, signatureType, payerOrigin);
        } else if (orderType == 3) {
            _executeV3Order(to, pool, orderInfo, signature, signatureType, payerOrigin);
        } else if (orderType == 4) {
            _executeV4Order(to, pool, orderInfo, signature, signatureType, payerOrigin);
        } else {
            revert("PMMAdapter: unsupported orderType");
        }
    }

    function _executeV1Order(
        address to,
        address pool,
        bytes memory orderInfo,
        bytes memory signature,
        uint256 signatureType,
        uint256 payerOrigin
    ) internal {
        IPMMProtocolV1.OrderRFQ memory order = abi.decode(orderInfo, (IPMMProtocolV1.OrderRFQ));
        uint256 flagsAndAmount;
        {
            uint256 amount = IERC20(order.takerAsset).balanceOf(address(this));
            if (amount > order.takerAmount) {
                amount = order.takerAmount;
            }
            require(amount > 0, "Zero balance of PMM adapter");
            SafeERC20.safeApprove(IERC20(order.takerAsset), pool, amount);
            flagsAndAmount = (signatureType == uint256(SignatureType.EIP1271) ? 1 << 254 : 0) + amount;
        }

        _call(
            pool,
            abi.encodeWithSelector(IPMMProtocolV1.fillOrderRFQTo.selector, order, signature, flagsAndAmount, to),
            order.rfqId
        );

        _handleRefund(order.takerAsset, payerOrigin);
    }

    function _executeV2Order(
        address to,
        address pool,
        bytes memory orderInfo,
        bytes memory signature,
        uint256 signatureType,
        uint256 payerOrigin
    ) internal {
        IPMMProtocolV2.OrderRFQ memory order = abi.decode(orderInfo, (IPMMProtocolV2.OrderRFQ));
        uint256 flagsAndAmount;
        uint256 fillMakerAmount;
        {
            uint256 amount = IERC20(order.takerAsset).balanceOf(address(this));
            if (amount > order.takerAmount) {
                amount = order.takerAmount;
            }
            require(amount > 0, "Zero balance of PMM adapter");
            SafeERC20.safeApprove(IERC20(order.takerAsset), pool, amount);
            flagsAndAmount = (signatureType == uint256(SignatureType.EIP1271) ? 1 << 254 : 0) + amount;
            fillMakerAmount =
                amount == order.takerAmount ? order.makerAmount : amount * order.makerAmount / order.takerAmount;
        }

        // V2 has no confidence (time-slippage) fields → confidence inputs are 0 (disabled).
        MakerBalanceCheck memory balanceCheck = MakerBalanceCheck({
            enabled: order.usePermit2 && order.permit2Signature.length > 0,
            makerAsset: order.makerAsset,
            maker: order.makerAddress,
            makerAmount: fillMakerAmount,
            confidenceT: 0,
            confidenceWeight: 0,
            confidenceCap: 0
        });

        _call(
            pool,
            abi.encodeWithSelector(IPMMProtocolV2.fillOrderRFQTo.selector, order, signature, flagsAndAmount, to),
            order.rfqId,
            balanceCheck
        );

        _handleRefund(order.takerAsset, payerOrigin);
    }

    function _executeV3Order(
        address to,
        address pool,
        bytes memory orderInfo,
        bytes memory signature,
        uint256 signatureType,
        uint256 payerOrigin
    ) internal {
        IPMMProtocolV3.OrderRFQ memory order = abi.decode(orderInfo, (IPMMProtocolV3.OrderRFQ));
        uint256 flagsAndAmount;
        uint256 fillMakerAmount;
        {
            uint256 amount = IERC20(order.takerAsset).balanceOf(address(this));
            if (amount > order.takerAmount) {
                amount = order.takerAmount;
            }
            require(amount > 0, "Zero balance of PMM adapter");
            SafeERC20.safeApprove(IERC20(order.takerAsset), pool, amount);
            flagsAndAmount = (signatureType == uint256(SignatureType.EIP1271) ? 1 << 254 : 0) + amount;
            fillMakerAmount =
                amount == order.takerAmount ? order.makerAmount : amount * order.makerAmount / order.takerAmount;
        }

        // Pass the already-decoded confidence fields through so the fallback balance
        // check never has to re-decode the whole order on the failure path.
        MakerBalanceCheck memory balanceCheck = MakerBalanceCheck({
            enabled: order.usePermit2 && order.permit2Signature.length > 0,
            makerAsset: order.makerAsset,
            maker: order.makerAddress,
            makerAmount: fillMakerAmount,
            confidenceT: order.confidenceT,
            confidenceWeight: order.confidenceWeight,
            confidenceCap: order.confidenceCap
        });

        // IPMMProtocol(pool).fillOrderRFQTo(order, signature, flagsAndAmount, to);
        _call(
            pool,
            abi.encodeWithSelector(IPMMProtocolV3.fillOrderRFQTo.selector, order, signature, flagsAndAmount, to),
            order.rfqId,
            balanceCheck
        );

        _handleRefund(order.takerAsset, payerOrigin);
    }

    function _executeV4Order(
        address to,
        address pool,
        bytes memory orderInfo,
        bytes memory signature,
        uint256 signatureType,
        uint256 payerOrigin
    ) internal {
        (OrderRFQLib.OrderRFQ memory order, CallerAuthData memory adaptorAuth, CallerAuthData memory protocolAuth) =
            abi.decode(orderInfo, (OrderRFQLib.OrderRFQ, CallerAuthData, CallerAuthData));

        _verifyCallerAuth(
            keccak256(abi.encode(order)),
            adaptorAuth.allowedCallers,
            adaptorAuth.nonce,
            adaptorAuth.authSig
        );

        if (order.allowedSender == address(0) || order.allowedSender != _extractDexRouterCaller()) {
            revert Errors.RFQ_BadSender(order.rfqId);
        }

        uint256 flagsAndAmount;
        {
            uint256 amount = IERC20(order.takerAsset).balanceOf(address(this));
            if (amount > order.takerAmount) {
                amount = order.takerAmount;
            }
            require(amount > 0, "Zero balance of PMM adapter");
            SafeERC20.safeApprove(IERC20(order.takerAsset), pool, amount);
            flagsAndAmount = (signatureType == uint256(SignatureType.EIP1271) ? 1 << 254 : 0) + amount;
        }

        _call(
            pool,
            abi.encodeWithSelector(
                IPMMProtocolV4.fillOrderRFQTo.selector,
                order,
                signature,
                flagsAndAmount,
                to,
                protocolAuth.allowedCallers,
                protocolAuth.nonce,
                protocolAuth.authSig
            ),
            order.rfqId
        );

        _handleRefund(order.takerAsset, payerOrigin);
    }

    function _handleRefund(address takerAsset, uint256 payerOrigin) internal {
        address _payerOrigin;
        if ((payerOrigin & MARKER_MASK) == ORIGIN_PAYER) {
            _payerOrigin = address(uint160(uint256(payerOrigin) & _ADDRESS_MASK));
        }
        uint256 amountLeft = IERC20(takerAsset).balanceOf(address(this));
        if (amountLeft > 0 && _payerOrigin != address(0)) {
            SafeERC20.safeTransfer(IERC20(takerAsset), _payerOrigin, amountLeft);
        }
    }

    function sellBase(address to, address pool, bytes memory moreInfo) external nonReentrant {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _PMMSwap(to, pool, moreInfo, payerOrigin);
    }

    function sellQuote(address to, address pool, bytes memory moreInfo) external nonReentrant {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
        }
        _PMMSwap(to, pool, moreInfo, payerOrigin);
    }

    /// @dev Legacy 3-arg entry point (V1 / non-Permit2). Forwards with the
    /// maker-balance recheck disabled, so behavior is byte-for-byte identical to before.
    function _call(address target, bytes memory data, uint256 rfqId) internal {
        _call(target, data, rfqId, MakerBalanceCheck(false, address(0), address(0), 0, 0, 0, 0));
    }

    function _call(address target, bytes memory data, uint256 rfqId, MakerBalanceCheck memory balanceCheck)
        internal
    {
        (bool success, bytes memory result) = target.call(data);
        if (success) {
            return;
        }
        if (result.length < 4) {
            // revert("RFQ: Unknown error");
            revert(string(abi.encodePacked("RFQ: Unknown error ", rfqId.toString())));
        }
        bytes4 selector;
        assembly {
            selector := mload(add(result, 0x20))
        }

        // All cases tested
        if (selector == 0x7d0bdf81) {
            // RFQ_InvalidMsgValue(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_InvalidMsgValue ", rfqId.toString())));
        } else if (selector == 0x1952c5f3) {
            // RFQ_ETHTransferFailed(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_ETHTransferFailed ", rfqId.toString())));
        } else if (selector == 0x8fde5c60) {
            // RFQ_ZeroTargetIsForbidden(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_ZeroTargetIsForbidden ", rfqId.toString())));
        } else if (selector == 0x87a26f41) {
            // RFQ_BadSignature(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_BadSignature ", rfqId.toString())));
        } else if (selector == 0x84935d57) {
            // RFQ_OrderExpired(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_OrderExpired ", rfqId.toString())));
        } else if (selector == 0x48872c38) {
            // RFQ_MakerAmountExceeded(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_MakerAmountExceeded ", rfqId.toString())));
        } else if (selector == 0x51c6158e) {
            // RFQ_TakerAmountExceeded(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_TakerAmountExceeded ", rfqId.toString())));
        } else if (selector == 0x94d42471) {
            // RFQ_SwapWithZeroAmount(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_SwapWithZeroAmount ", rfqId.toString())));
        } else if (selector == 0x6fe432b3) {
            // RFQ_InvalidatedOrder(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_InvalidatedOrder ", rfqId.toString())));
        } else if (selector == 0xf4a08977) {
            // RFQ_EthDepositRejected()
            // Won't be triggerred here unless `data` is empty
            revert("RFQ_EthDepositRejected");
        } else if (selector == 0xf4059071) {
            // SafeTransferFromFailed()
            revert(string(abi.encodePacked("RFQ_SafeTransferFromFailed ", rfqId.toString())));
        } else if (selector == 0x8112e119) {
            // Permit2TransferAmountTooHigh()
            revert(string(abi.encodePacked("RFQ_Permit2TransferAmountTooHigh ", rfqId.toString())));
        } else if (selector == 0xfb7f5079) {
            // SafeTransferFailed()
            revert(string(abi.encodePacked("RFQ_SafeTransferFailed ", rfqId.toString())));
        } else if (selector == 0x19be9a90) {
            // ForceApproveFailed()
            revert(string(abi.encodePacked("RFQ_ForceApproveFailed ", rfqId.toString())));
        } else if (selector == 0x8216cd1c) {
            // SafeIncreaseAllowanceFailed()
            revert(string(abi.encodePacked("RFQ_SafeIncreaseAllowanceFailed ", rfqId.toString())));
        } else if (selector == 0x840bdf26) {
            // SafeDecreaseAllowanceFailed()
            revert(string(abi.encodePacked("RFQ_SafeDecreaseAllowanceFailed ", rfqId.toString())));
        } else if (selector == 0x68275857) {
            // SafePermitBadLength()
            revert(string(abi.encodePacked("RFQ_SafePermitBadLength ", rfqId.toString())));
        } else if (selector == 0xc6f643b2) {
            // RFQ_AmountTooLarge(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_AmountTooLarge ", rfqId.toString())));
        } else if (selector == 0xa1475d7b) {
            // RFQ_SettlementAmountTooSmall(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_SettlementAmountTooSmall ", rfqId.toString())));
        } else if (selector == 0x589584f5) {
            // RFQ_OrderAlreadyCancelledOrUsed(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_OrderAlreadyCancelledOrUsed ", rfqId.toString())));
        } else if (selector == 0x1204d22d) {
            // RFQ_ConfidenceCapExceeded(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_ConfidenceCapExceeded ", rfqId.toString())));
        } else if (selector == Errors.RFQ_BadSender.selector) {
            // RFQ_BadSender(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_BadSender ", rfqId.toString())));
        } else if (selector == Errors.RFQ_InvalidRfqId.selector) {
            // RFQ_InvalidRfqId(uint256 rfqId);
            revert(string(abi.encodePacked("RFQ_InvalidRfqId ", rfqId.toString())));
        } else if (selector == CallerAuth.AUTH_ZeroSigner.selector) {
            revert(string(abi.encodePacked("AUTH_ZeroSigner ", rfqId.toString())));
        } else if (selector == CallerAuth.AUTH_UntrustedCaller.selector) {
            revert(string(abi.encodePacked("AUTH_UntrustedCaller ", rfqId.toString())));
        } else if (selector == CallerAuth.AUTH_BadAuthSig.selector) {
            revert(string(abi.encodePacked("AUTH_BadAuthSig ", rfqId.toString())));
        } else if (selector == CallerAuth.AUTH_BadSigLen.selector) {
            revert(string(abi.encodePacked("AUTH_BadSigLen ", rfqId.toString())));
        } else if (selector == CallerAuth.AUTH_NonceUsed.selector) {
            revert(string(abi.encodePacked("AUTH_NonceUsed ", rfqId.toString())));
        } else if (selector == CallerAuth.AUTH_BadCallersLength.selector) {
            revert(string(abi.encodePacked("AUTH_BadCallersLength ", rfqId.toString())));
        } else {
            // Fallback: the underlying revert selector matched none of the known cases above.
            // Only for enabled (Permit2) orders do we attempt a read-only maker
            // balance recheck to attribute the failure to insufficient maker balance.
            if (balanceCheck.enabled) {
                (uint256 balance, bool ok) = _safeBalanceOf(balanceCheck.makerAsset, balanceCheck.maker);
                // Stage 1: compare against the fill's makerAmount. If the maker can cover the
                // payout, the failure is unrelated to balance → keep RFQ_Failed.
                if (ok && balance < balanceCheck.makerAmount) {
                    // Stage 2: below the payout → recompute the confidence-adjusted
                    // (time-slippage) threshold and compare against that. V2 orders carry
                    // zeroed confidence inputs, so the helper returns makerAmount unchanged.
                    uint256 required = _getMakerAmountForBalanceCheck(
                        balanceCheck.makerAmount,
                        balanceCheck.confidenceT,
                        balanceCheck.confidenceWeight,
                        balanceCheck.confidenceCap
                    );
                    if (balance < required) {
                        // Even at maximum slippage the maker cannot cover the payout →
                        // attribute to a maker transfer failure (same string as selector 0xf4059071).
                        revert(string(abi.encodePacked("RFQ_SafeTransferFromFailed ", rfqId.toString())));
                    }
                }
                // balance >= required (or staticcall failed / short return) → safe degrade
                // to the generic RFQ_Failed, never changing existing failure semantics.
            }
            revert(string(abi.encodePacked("RFQ_Failed ", rfqId.toString())));
        }
    }

    /// @dev Read-only ERC20 balanceOf via staticcall. Returns `(0, false)` when the call
    /// reverts or returns fewer than 32 bytes, so callers can safely degrade. No state
    /// writes, no transfers, no new reentrancy surface.
    function _safeBalanceOf(address token, address account) private view returns (uint256 bal, bool ok) {
        (bool success, bytes memory data) =
            token.staticcall(abi.encodeWithSelector(IERC20.balanceOf.selector, account));
        if (success && data.length >= 32) {
            return (abi.decode(data, (uint256)), true);
        }
        return (0, false);
    }

    // keep in sync with PmmProtocol.sol L263-279
    /// @dev Mirrors PmmProtocol's confidence (time-slippage) reduction to derive the
    /// effective maker payout used as the maker-balance threshold. Returns `makerAmount`
    /// unchanged when slippage is disabled (confidenceT/Weight/Cap == 0) or out of bounds.
    function _getMakerAmountForBalanceCheck(
        uint256 makerAmount,
        uint256 confidenceT,
        uint256 confidenceWeight,
        uint256 confidenceCap
    ) private view returns (uint256) {
        if (confidenceT != 0 && block.timestamp > confidenceT) {
            if (confidenceWeight != 0 && confidenceCap != 0 && confidenceCap <= _CONFIDENCE_CAP_LIMIT) {
                uint256 cutdownPercentageX6 = (block.timestamp - confidenceT) * confidenceWeight;
                if (cutdownPercentageX6 > confidenceCap) {
                    cutdownPercentageX6 = confidenceCap;
                }
                makerAmount = makerAmount - makerAmount * cutdownPercentageX6 / 1e6;
            }
        }
        return makerAmount;
    }
}
