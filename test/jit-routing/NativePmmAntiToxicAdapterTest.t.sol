// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "./AntiArbTestBase.t.sol";
import {IAdapter} from "@dex/interfaces/IAdapter.sol";
import {INativeRfqPoolV3} from "@dex/interfaces/INativeRfqPoolV3.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";
import {CallerAuth} from "@dex/libraries/CallerAuth.sol";
import {NativePmmAntiToxicAdapter} from "@dex/adapter/NativePmmAntiToxicAdapter.sol";
import {MockERC20} from "../common/mock/MockERC20.sol";

contract MockWETH is MockERC20 {
    constructor() MockERC20("Wrapped Ether", "WETH", 0) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}

/// @dev Minimal RFQ pool: pulls `actual` sellerToken from the adapter and pays a fixed
///      `quote.buyerTokenAmount` of buyerToken back to it.
contract MockNativeRfqPool {
    error TradeFailed();

    uint256 public lastActualAmountIn;
    uint256 public lastValue;
    bool public failTrade;

    function setFailTrade(bool fail) external {
        failTrade = fail;
    }

    function tradeRFQT(INativeRfqPoolV3.RFQTQuote memory quote, uint256 actual, uint256) external payable {
        if (failTrade) revert TradeFailed();
        require(quote.sellerToken == address(0) ? msg.value == actual : msg.value == 0, "value mismatch");
        lastActualAmountIn = actual;
        lastValue = msg.value;
        if (quote.sellerToken != address(0)) {
            IERC20(quote.sellerToken).transferFrom(msg.sender, address(this), actual);
        }
        if (quote.buyerToken == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: quote.buyerTokenAmount}("");
            require(success, "native output failed");
        } else {
            IERC20(quote.buyerToken).transfer(msg.sender, quote.buyerTokenAmount);
        }
    }

    receive() external payable {}
}

/// @title NativePmmAntiToxicAdapterTest
contract NativePmmAntiToxicAdapterTest is AntiArbTestBase {
    NativePmmAntiToxicAdapter internal adapter;
    MockNativeRfqPool internal mockPool;
    MockERC20 internal sellerToken;
    MockERC20 internal buyerToken;
    MockWETH internal weth;

    address internal recipient = makeAddr("recipient");
    address internal trader = makeAddr("trader"); // the dexRouterCaller == beneficiary
    address internal refundToAddr = makeAddr("refundTo");

    uint256 internal constant QUOTED_SELLER = 100e18;
    uint256 internal constant QUOTED_BUYER = 200e18;

    function setUp() public {
        _setUpSigner();
        mockPool = new MockNativeRfqPool();
        weth = new MockWETH();
        adapter = new NativePmmAntiToxicAdapter(address(weth), address(mockPool), authSigner);
        sellerToken = new MockERC20("Seller", "SELL", 0);
        buyerToken = new MockERC20("Buyer", "BUY", 0);
        buyerToken.mint(address(mockPool), 1_000e18); // pool inventory to pay out
    }

    // ============================ Beneficiary binding ============================

    /// beneficiary == dexRouterCaller (both non-zero) -> trade succeeds, output delivered.
    function test_beneficiary_matches_succeeds() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);

        assertEq(buyerToken.balanceOf(recipient), QUOTED_BUYER, "recipient receives quoted buyer amount");
        assertEq(sellerToken.balanceOf(address(adapter)), 0, "no seller leftover on adapter");
    }

    /// beneficiary != dexRouterCaller -> revert("beneficiary mismatch").
    function test_beneficiary_mismatch_reverts() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        // Signed beneficiary = trader, but the injected dexRouterCaller = a different address.
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        address otherCaller = makeAddr("otherCaller");
        vm.expectRevert("beneficiary mismatch");
        _callAdapter(false, recipient, address(mockPool), moreInfo, otherCaller, refundToAddr);
    }

    /// A missing marker resolves dexRouterCaller to zero and fails closed.
    function test_missing_caller_marker_reverts() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        vm.expectRevert("beneficiary mismatch");
        _callAdapterNoCallerMarker(recipient, address(mockPool), moreInfo, refundToAddr);
    }

    /// A zero beneficiary and zero dexRouterCaller must not pass.
    function test_both_zero_reverts() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        // Signed beneficiary = address(0); inject a marked -64 word carrying address(0).
        bytes memory moreInfo = _buildMoreInfo(address(0), _one(address(this)), 1);

        vm.expectRevert("beneficiary mismatch");
        _callAdapter(false, recipient, address(mockPool), moreInfo, address(0), refundToAddr);
    }

    // ============================ Caller binding ============================

    /// msg.sender not in allowedCallers -> AUTH_UntrustedCaller (recipient/pool match, sig valid).
    function test_untrusted_caller_reverts() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        // allowedCallers signed for a different relayer; this contract is the actual caller.
        bytes memory moreInfo = _buildMoreInfo(trader, _one(makeAddr("otherRelayer")), 1);

        vm.expectRevert(CallerAuth.AUTH_UntrustedCaller.selector);
        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);
    }

    // ============================ Recipient and router binding ============================

    /// Quote output must land on the adapter first.
    function test_bad_quote_recipient_reverts() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        INativeRfqPoolV3.RFQTQuote memory q = _mkQuote();
        q.recipient = recipient;
        bytes memory moreInfo = _buildMoreInfoFromQuote(q, trader, _one(address(this)), 1);

        vm.expectRevert("bad recipient");
        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);
    }

    /// The IAdapter `pool` argument is ignored; the immutable NATIVE_ROUTER is used.
    function test_pool_arg_ignored_uses_native_router() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        _callAdapter(false, recipient, makeAddr("attackerPool"), moreInfo, trader, refundToAddr);

        assertEq(buyerToken.balanceOf(recipient), QUOTED_BUYER, "output came from immutable router");
    }

    function test_native_router_revert_bubbles() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);
        mockPool.setFailTrade(true);

        vm.expectRevert(MockNativeRfqPool.TradeFailed.selector);
        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);
    }

    // ============================ Output forwarding ============================

    function test_full_output_balance_forwarded() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        uint256 existingBalance = 500e18;
        buyerToken.mint(address(adapter), existingBalance);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);

        assertEq(buyerToken.balanceOf(recipient), existingBalance + QUOTED_BUYER, "full output forwarded");
        assertEq(buyerToken.balanceOf(address(adapter)), 0, "no output left on adapter");
    }

    function test_full_native_output_and_existing_weth_forwarded() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        uint256 existingWeth = 3 ether;
        uint256 nativeOutput = 2 ether;
        vm.deal(address(this), existingWeth);
        weth.deposit{value: existingWeth}();
        weth.transfer(address(adapter), existingWeth);
        vm.deal(address(mockPool), nativeOutput);

        INativeRfqPoolV3.RFQTQuote memory q = _mkQuote();
        q.buyerToken = address(0);
        q.buyerTokenAmount = nativeOutput;
        bytes memory moreInfo = _buildMoreInfoFromQuote(q, trader, _one(address(this)), 1);

        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);

        assertEq(weth.balanceOf(recipient), existingWeth + nativeOutput, "full WETH output forwarded");
        assertEq(weth.balanceOf(address(adapter)), 0, "no WETH left on adapter");
        assertEq(address(adapter).balance, 0, "no ETH left on adapter");
    }

    // ============================ Input cap and refund ============================

    function test_input_cap_returns_excess_to_refundTo() public {
        uint256 funded = 250e18; // >> 110% of QUOTED_SELLER(100e18)
        sellerToken.mint(address(adapter), funded);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);

        uint256 consumed = (QUOTED_SELLER * 109) / 100; // 109e18
        uint256 expectedRefund = funded - consumed; // 141e18
        assertEq(sellerToken.balanceOf(refundToAddr), expectedRefund, "excess refunded to refundTo");
        assertEq(sellerToken.balanceOf(trader), 0, "bound caller does not receive refund");
        assertEq(sellerToken.balanceOf(address(adapter)), 0, "no seller dust left on adapter");
        assertEq(buyerToken.balanceOf(recipient), QUOTED_BUYER, "output still delivered");
    }

    function test_native_input_cap_matches_call_value() public {
        uint256 funded = 250e18;
        vm.deal(address(this), funded);
        weth.deposit{value: funded}();
        weth.transfer(address(adapter), funded);

        INativeRfqPoolV3.RFQTQuote memory q = _mkQuote();
        q.sellerToken = address(0);
        bytes memory moreInfo = _buildMoreInfoFromQuote(q, trader, _one(address(this)), 1);

        uint256 refundBalanceBefore = refundToAddr.balance;
        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);

        uint256 consumed = (QUOTED_SELLER * 109) / 100;
        assertEq(mockPool.lastActualAmountIn(), consumed, "native input capped");
        assertEq(mockPool.lastValue(), consumed, "msg.value matches capped input");
        assertEq(refundToAddr.balance - refundBalanceBefore, funded - consumed, "excess ETH refunded");
        assertEq(trader.balance, 0, "bound caller does not receive refund");
        assertEq(address(adapter).balance, 0, "no ETH left on adapter");
        assertEq(weth.balanceOf(address(adapter)), 0, "no WETH left on adapter");
        assertEq(buyerToken.balanceOf(recipient), QUOTED_BUYER, "output still delivered");
    }

    function test_missing_refund_marker_reverts_without_consuming_nonce() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        vm.expectRevert("invalid refundTo");
        _callAdapterWithRefundWord(
            recipient, address(mockPool), moreInfo, trader, uint256(uint160(refundToAddr))
        );

        _callAdapter(false, recipient, address(mockPool), moreInfo, trader, refundToAddr);
        assertEq(buyerToken.balanceOf(recipient), QUOTED_BUYER, "nonce rolled back with failed call");
    }

    function test_forged_refund_marker_reverts() public {
        sellerToken.mint(address(adapter), QUOTED_SELLER);
        bytes memory moreInfo = _buildMoreInfo(trader, _one(address(this)), 1);

        vm.expectRevert("invalid refundTo");
        _callAdapterWithRefundWord(recipient, address(mockPool), moreInfo, trader, type(uint256).max);
    }

    // ================================ helpers ================================

    /// @dev Builds a zeroed RFQTQuote with only the fields the adapter reads populated.
    function _mkQuote() internal view returns (INativeRfqPoolV3.RFQTQuote memory q) {
        q.pool = address(mockPool);
        q.recipient = address(adapter);
        q.sellerToken = address(sellerToken);
        q.buyerToken = address(buyerToken);
        q.sellerTokenAmount = QUOTED_SELLER;
        q.buyerTokenAmount = QUOTED_BUYER;
    }

    /// @dev Builds & ABI-encodes a signed MoreInfo payload for the adapter.
    function _buildMoreInfo(address beneficiary, address[] memory allowedCallers, uint256 nonce)
        internal
        view
        returns (bytes memory)
    {
        return _buildMoreInfoFromQuote(_mkQuote(), beneficiary, allowedCallers, nonce);
    }

    function _buildMoreInfoFromQuote(
        INativeRfqPoolV3.RFQTQuote memory q,
        address beneficiary,
        address[] memory allowedCallers,
        uint256 nonce
    ) internal view returns (bytes memory) {
        bytes memory sig = _signNative(address(adapter), abi.encode(q), beneficiary, allowedCallers, nonce);
        NativePmmAntiToxicAdapter.MoreInfo memory info = NativePmmAntiToxicAdapter.MoreInfo({
            quote: q,
            beneficiary: beneficiary,
            allowedCallers: allowedCallers,
            nonce: nonce,
            authSig: sig
        });
        return abi.encode(info);
    }

    /// @dev Calls the adapter with the CommonLib tail layout: dexRouterCaller at -64 + refundTo at -32.
    function _callAdapter(
        bool reverse,
        address to_,
        address pool_,
        bytes memory moreInfo,
        address dexRouterCaller,
        address refundTo_
    ) internal {
        bytes4 sel = reverse ? IAdapter.sellQuote.selector : IAdapter.sellBase.selector;
        bytes memory head = abi.encodeWithSelector(sel, to_, pool_, moreInfo);
        bytes memory payload = abi.encodePacked(
            head,
            DEX_ROUTER_CALLER_MARKER + uint256(uint160(dexRouterCaller)),
            ORIGIN_PAYER_MARKER + uint256(uint160(refundTo_))
        );
        (bool ok, bytes memory ret) = address(adapter).call(payload);
        if (!ok) _bubble(ret);
    }

    /// @dev Calls the adapter WITHOUT a valid dexRouterCaller marker at -64 (marker absent -> extract 0).
    function _callAdapterNoCallerMarker(address to_, address pool_, bytes memory moreInfo, address refundTo_)
        internal
    {
        bytes memory head = abi.encodeWithSelector(IAdapter.sellBase.selector, to_, pool_, moreInfo);
        // Only the -32 refundTo word is appended; the word landing at -64 is unmarked payload -> 0.
        bytes memory payload = abi.encodePacked(head, ORIGIN_PAYER_MARKER + uint256(uint160(refundTo_)));
        (bool ok, bytes memory ret) = address(adapter).call(payload);
        if (!ok) _bubble(ret);
    }

    function _callAdapterWithRefundWord(
        address to_,
        address pool_,
        bytes memory moreInfo,
        address dexRouterCaller,
        uint256 refundWord
    ) internal {
        bytes memory head = abi.encodeWithSelector(IAdapter.sellBase.selector, to_, pool_, moreInfo);
        bytes memory payload = abi.encodePacked(
            head,
            DEX_ROUTER_CALLER_MARKER + uint256(uint160(dexRouterCaller)),
            refundWord
        );
        (bool ok, bytes memory ret) = address(adapter).call(payload);
        if (!ok) _bubble(ret);
    }

    function _bubble(bytes memory ret) internal pure {
        assembly {
            revert(add(ret, 0x20), mload(ret))
        }
    }
}
