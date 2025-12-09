// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@dex/libraries/ExtraDataLib.sol";
import "@dex/interfaces/IDexRouter.sol";
import "./CommissionHelper.t.sol";
import "./TrimHelper.t.sol";
import "./Permit2Helper.t.sol";

contract ExtraDataLibTestHelper is ExtraDataLib {
    function getExtraData(bytes memory data) public view returns (ExtraData memory) {
        return getDecodedExtraData();
    }
}

contract ExtraDataLibTest is Test, CommissionHelper, TrimHelper, Permit2Helper {
    ExtraDataLibTestHelper extraDataLibTestHelper;

    // swapData
    bytes public emptyData = abi.encodePacked(bytes32(0), bytes32(0), bytes32(0), bytes32(0), bytes32(0));
    // commission data
    address public token = makeAddr("token");
    bool public isFromTokenCommission = true;
    bool public isToBCommission = true;
    uint256 public commissionReferrerNum = 8;
    address[] public referrerAddresses = new address[](commissionReferrerNum);
    uint256[] public commissionRates = new uint256[](commissionReferrerNum);
    // trim data
    uint256 public trimRate = 1000;
    uint256 public chargeRate = 400;
    uint256 public expectAmountOut = 10 ** 18;
    address public trimAddress = makeAddr("trimAddress");
    address public chargeAddress = makeAddr("chargeAddress");
    bool public isToBTrim = true;
    // permit2 data
    uint256 public permit2AmountsLength = 9;
    uint256[] public maxAmounts = new uint256[](permit2AmountsLength);
    uint256 public nonce = 1;
    uint256 public deadline = 2524579200;
    address public owner = makeAddr("owner");
    bytes public signature = hex"2b0d243e41998a4480daa60c8822eb7d29b06ac7fca6f858083d8e6e59fc508645411d46f84e95e0b5eda9b6af9d4ec6c3b6b4cc47fbe0249a7319f86d92afd71c";
    // refund to data
    address public refundTo = makeAddr("refundTo");

    constructor() {
        for (uint256 i = 0; i < commissionReferrerNum; i++) {
            referrerAddresses[i] = makeAddr(string(abi.encodePacked("referrerAddress", i)));
            commissionRates[i] = (i + 1) * 100000;
        }
        for (uint256 i = 0; i < permit2AmountsLength; i++) {
            maxAmounts[i] = (i + 1) * 10 ** 18;
        }
    }

    function setUp() public {
        extraDataLibTestHelper = new ExtraDataLibTestHelper();
    }

    // 1 extra data type
    function test_getExtraData_onlyCommission() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory data = bytes.concat(emptyData, commissionData);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
        }
    }

    function test_getExtraData_onlyTrim() public {
        // only trim, trimData length is 64 bytes
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory data = bytes.concat(emptyData, trimData);
        IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
        _assertTrimInfo(extraData.trimInfo, true);
        // trim and charge, trimData length is 96 bytes
        trimData = _generateTrimDataTrimAndCahrge();
        data = bytes.concat(emptyData, trimData);
        extraData = extraDataLibTestHelper.getExtraData(data);
        _assertTrimInfo(extraData.trimInfo, false);
    }

    function test_getExtraData_onlyPermit2() public {
        for (uint256 i = 1; i <= 9; i++) {
            bytes memory permit2Data = _generatePermit2Data(i);
            bytes memory data = bytes.concat(emptyData, permit2Data);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertPermit2Info(extraData.permit2Info, i);
        }
    }

    function test_getExtraData_onlyRefundTo() public {
        bytes memory refundToData = _generateRefundToData();
        bytes memory data = bytes.concat(emptyData, refundToData);
        IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
        _assertRefundTo(extraData.refundTo);
    }

    // 2 extra data types
    function test_getExtraData_commissionAndTrim() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            // only trim, trimData length is 64 bytes
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory data = bytes.concat(emptyData, trimData, commissionData);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
            _assertTrimInfo(extraData.trimInfo, true);
            // trim and charge, trimData length is 96 bytes
            trimData = _generateTrimDataTrimAndCahrge();
            data = bytes.concat(emptyData, trimData, commissionData);
            extraData = extraDataLibTestHelper.getExtraData(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
            _assertTrimInfo(extraData.trimInfo, false);
        }
    }

    function test_getExtraData_commissionAndPermit2() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                bytes memory commissionData = _generateCommissionData(i);
                bytes memory permit2Data = _generatePermit2Data(j);
                bytes memory data = bytes.concat(emptyData, permit2Data, commissionData);
                IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j);
            }
        }
    }

    function test_getExtraData_commissionAndRefundTo() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory refundToData = _generateRefundToData();
            bytes memory data = bytes.concat(emptyData, refundToData, commissionData);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
            _assertRefundTo(extraData.refundTo);
        }
    }

    function test_getExtraData_trimAndPermit2() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            // only trim, trimData length is 64 bytes
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory permit2Data = _generatePermit2Data(i);
            bytes memory data = bytes.concat(emptyData, permit2Data, trimData);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertPermit2Info(extraData.permit2Info, i);
            // trim and charge, trimData length is 96 bytes
            trimData = _generateTrimDataTrimAndCahrge();
            data = bytes.concat(emptyData, permit2Data, trimData);
            extraData = extraDataLibTestHelper.getExtraData(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertPermit2Info(extraData.permit2Info, i);
        }
    }

    function test_getExtraData_trimAndRefundTo() public {
        // only trim, trimData length is 64 bytes
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory refundToData = _generateRefundToData();
        bytes memory data = bytes.concat(emptyData, refundToData, trimData);
        IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
        _assertTrimInfo(extraData.trimInfo, true);
        _assertRefundTo(extraData.refundTo);
        // trim and charge, trimData length is 96 bytes
        trimData = _generateTrimDataTrimAndCahrge();
        data = bytes.concat(emptyData, refundToData, trimData);
        extraData = extraDataLibTestHelper.getExtraData(data);
        _assertTrimInfo(extraData.trimInfo, false);
        _assertRefundTo(extraData.refundTo);
    }

    function test_getExtraData_permit2AndRefundTo() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            bytes memory permit2Data = _generatePermit2Data(i);
            bytes memory refundToData = _generateRefundToData();
            bytes memory data = bytes.concat(emptyData, refundToData, permit2Data);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertPermit2Info(extraData.permit2Info, i);
            _assertRefundTo(extraData.refundTo);
        }
    }

    // 3 extra data types
    function test_getExtraData_commissionAndTrimAndPermit2() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                // only trim, trimData length is 64 bytes
                bytes memory commissionData = _generateCommissionData(i);
                bytes memory trimData = _generateTrimDataOnlyTrim();
                bytes memory permit2Data = _generatePermit2Data(j);
                bytes memory data = bytes.concat(emptyData, permit2Data, trimData, commissionData);
                IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
                _assertTrimInfo(extraData.trimInfo, true);
                _assertPermit2Info(extraData.permit2Info, j);
                _assertCommissionInfo(extraData.commissionInfo, i);
                // trim and charge, trimData length is 96 bytes
                trimData = _generateTrimDataTrimAndCahrge();
                data = bytes.concat(emptyData, permit2Data, trimData, commissionData);
                extraData = extraDataLibTestHelper.getExtraData(data);
                _assertTrimInfo(extraData.trimInfo, false);
                _assertPermit2Info(extraData.permit2Info, j);
                _assertCommissionInfo(extraData.commissionInfo, i);
            }
        }
    }

    function test_getExtraData_commissionAndTrimAndRefundTo() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            // only trim, trimData length is 64 bytes
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory refundToData = _generateRefundToData();
            bytes memory data = bytes.concat(emptyData, refundToData, trimData, commissionData);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertRefundTo(extraData.refundTo);
            _assertCommissionInfo(extraData.commissionInfo, i);
            // trim and charge, trimData length is 96 bytes
            trimData = _generateTrimDataTrimAndCahrge();
            data = bytes.concat(emptyData, refundToData, trimData, commissionData);
            extraData = extraDataLibTestHelper.getExtraData(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertRefundTo(extraData.refundTo);
            _assertCommissionInfo(extraData.commissionInfo, i);
        }
    }

    function test_getExtraData_commissionAndPermit2AndRefundTo() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                bytes memory commissionData = _generateCommissionData(i);
                bytes memory permit2Data = _generatePermit2Data(j);
                bytes memory refundToData = _generateRefundToData();
                bytes memory data = bytes.concat(emptyData, refundToData, permit2Data, commissionData);
                IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
                _assertRefundTo(extraData.refundTo);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j);
            }
        }
    }

    function test_getExtraData_trimAndPermit2AndRefundTo() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            // only trim, trimData length is 64 bytes
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory permit2Data = _generatePermit2Data(i);
            bytes memory refundToData = _generateRefundToData();
            bytes memory data = bytes.concat(emptyData, refundToData, permit2Data, trimData);
            IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertPermit2Info(extraData.permit2Info, i);
            _assertRefundTo(extraData.refundTo);
            // trim and charge, trimData length is 96 bytes
            trimData = _generateTrimDataTrimAndCahrge();
            data = bytes.concat(emptyData, refundToData, permit2Data, trimData);
            extraData = extraDataLibTestHelper.getExtraData(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertPermit2Info(extraData.permit2Info, i);
            _assertRefundTo(extraData.refundTo);
        }
    }

    // 4 extra data types
    function test_getExtraData_all() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                // only trim, trimData length is 64 bytes
                bytes memory commissionData = _generateCommissionData(i);
                bytes memory trimData = _generateTrimDataOnlyTrim();
                bytes memory permit2Data = _generatePermit2Data(j);
                bytes memory refundToData = _generateRefundToData();
                bytes memory data = bytes.concat(emptyData, refundToData, permit2Data, trimData, commissionData);
                IDexRouter.ExtraData memory extraData = extraDataLibTestHelper.getExtraData(data);
                _assertTrimInfo(extraData.trimInfo, true);
                _assertPermit2Info(extraData.permit2Info, j);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertRefundTo(extraData.refundTo);
                // trim and charge, trimData length is 96 bytes
                trimData = _generateTrimDataTrimAndCahrge();
                data = bytes.concat(emptyData, refundToData, permit2Data, trimData, commissionData);
                extraData = extraDataLibTestHelper.getExtraData(data);
                _assertTrimInfo(extraData.trimInfo, false);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j);
                _assertRefundTo(extraData.refundTo);
            }
        }
    }

    // ==================== Internal functions for generate extra data ====================
    function _generateCommissionData(uint256 referrerNum_) internal view returns (bytes memory) {
        uint256[] memory commissionRates_ = new uint256[](referrerNum_);
        address[] memory referrerAddresses_ = new address[](referrerNum_);
        for (uint256 i = 0; i < referrerNum_; i++) {
            commissionRates_[i] = commissionRates[i];
            referrerAddresses_[i] = referrerAddresses[i];
        }
        return _buildCommissionInfoUnified(
            isFromTokenCommission, // isFromTokenCommission
            !isFromTokenCommission, // isToTokenCommission
            token, // token
            isToBCommission, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
    }

    function _generateTrimDataOnlyTrim() internal view returns (bytes memory) {
        return _buildTrimInfoUnified(
            trimRate,
            trimAddress,
            expectAmountOut,
            0,
            address(0),
            isToBTrim
        );
    }

    function _generateTrimDataTrimAndCahrge() internal view returns (bytes memory) {
        return _buildTrimInfoUnified(
            trimRate,
            trimAddress,
            expectAmountOut,
            chargeRate,
            chargeAddress,
            isToBTrim
        );
    }

    function _generatePermit2Data(uint256 maxAmountsLength_) internal view returns (bytes memory) {
        uint256[] memory maxAmounts_ = new uint256[](maxAmountsLength_);
        for (uint256 i = 0; i < maxAmountsLength_; i++) {
            maxAmounts_[i] = maxAmounts[i];
        }
        return _buildPermit2InfoUnifiedBatch(
            maxAmounts_,
            nonce,
            deadline,
            owner,
            signature
        );
    }

    function _generateRefundToData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0xac3a7da8b1c60000000000000000000000000000000000000000000000000000 | uint256(uint160(refundTo))));
    }

    // ==================== Internal functions for assert extra data ====================
    function _assertCommissionInfo(IDexRouter.CommissionInfo memory commissionInfo, uint256 referrerNum_) internal {
        assertEq(commissionInfo.toBCommission, isToBCommission ? 2 : 1, "toBCommission mismatch");
        uint256 commissionLength = commissionInfo.commissionLength;
        assertEq(commissionInfo.isFromTokenCommission, isFromTokenCommission, "isFromTokenCommission mismatch");
        assertEq(commissionInfo.isToTokenCommission, !isFromTokenCommission, "isToTokenCommission mismatch");
        assertEq(address(uint160(commissionInfo.tokenWithMode)), token, "token mismatch");
        assertEq(commissionLength, referrerNum_, "commissionLength mismatch");
        assertEq(commissionInfo.referrerAddress, referrerAddresses[0], "referrerAddress mismatch");
        assertEq(commissionInfo.commissionRate, commissionRates[0], "commissionRate mismatch");
        if (commissionLength > 1) {
            assertEq(commissionInfo.referrerAddress2, referrerAddresses[1], "referrerAddress2 mismatch");
            assertEq(commissionInfo.commissionRate2, commissionRates[1], "commissionRate2 mismatch");
        }
        if (commissionLength > 2) {
            assertEq(commissionInfo.referrerAddress3, referrerAddresses[2], "referrerAddress3 mismatch");
            assertEq(commissionInfo.commissionRate3, commissionRates[2], "commissionRate3 mismatch");
        }
        if (commissionLength > 3) {
            assertEq(commissionInfo.referrerAddress4, referrerAddresses[3], "referrerAddress4 mismatch");
            assertEq(commissionInfo.commissionRate4, commissionRates[3], "commissionRate4 mismatch");
        }
        if (commissionLength > 4) {
            assertEq(commissionInfo.referrerAddress5, referrerAddresses[4], "referrerAddress5 mismatch");
            assertEq(commissionInfo.commissionRate5, commissionRates[4], "commissionRate5 mismatch");
        }
        if (commissionLength > 5) {
            assertEq(commissionInfo.referrerAddress6, referrerAddresses[5], "referrerAddress6 mismatch");
            assertEq(commissionInfo.commissionRate6, commissionRates[5], "commissionRate6 mismatch");
        }
        if (commissionLength > 6) {
            assertEq(commissionInfo.referrerAddress7, referrerAddresses[6], "referrerAddress7 mismatch");
            assertEq(commissionInfo.commissionRate7, commissionRates[6], "commissionRate7 mismatch");
        }
        if (commissionLength > 7) {
            assertEq(commissionInfo.referrerAddress8, referrerAddresses[7], "referrerAddress8 mismatch");
            assertEq(commissionInfo.commissionRate8, commissionRates[7], "commissionRate8 mismatch");
        }
    }

    function _assertTrimInfo(IDexRouter.TrimInfo memory trimInfo, bool isOnlyTrim_) internal {
        assertEq(trimInfo.hasTrim, true, "hasTrim mismatch");
        assertEq(trimInfo.trimRate, trimRate, "trimRate mismatch");
        assertEq(trimInfo.trimAddress, trimAddress, "trimAddress mismatch");
        assertEq(trimInfo.expectAmountOut, expectAmountOut, "expectAmountOut mismatch");
        if (isOnlyTrim_) {
            assertEq(trimInfo.chargeRate, 0, "chargeRate mismatch");
            assertEq(trimInfo.chargeAddress, address(0), "chargeAddress mismatch");
        } else {
            assertEq(trimInfo.chargeRate, chargeRate, "chargeRate mismatch");
            assertEq(trimInfo.chargeAddress, chargeAddress, "chargeAddress mismatch");
        }
        assertEq(trimInfo.toBTrim, isToBTrim ? 2 : 1, "toBTrim mismatch");
    }

    function _assertPermit2Info(IDexRouter.Permit2Info memory permit2Info, uint256 maxAmountsLength_) internal {
        assertEq(permit2Info.amounts.length, maxAmountsLength_, "maxAmounts length mismatch");
        for (uint256 i = 0; i < maxAmountsLength_; i++) {
            assertEq(permit2Info.amounts[i], maxAmounts[i], "maxAmounts mismatch");
        }
        assertEq(permit2Info.nonce, nonce, "nonce mismatch");
        assertEq(permit2Info.deadline, deadline, "deadline mismatch");
        assertEq(permit2Info.owner, owner, "owner mismatch");
        assertEq(permit2Info.signature, signature, "signature mismatch");
    }

    function _assertRefundTo(address refundTo_) internal {
        assertEq(refundTo_, refundTo, "refundTo mismatch");
    }
}