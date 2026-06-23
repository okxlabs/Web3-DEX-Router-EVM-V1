// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExtraDataLibTestBase.t.sol";

/// @title ExtraDataLibTest
/// @notice Test cases for correct calldata concatenation order of ExtraDataLib
/// @dev The correct order should be: swapData + refundToData + permit2Data + trimData + commissionData
///      These tests verify that correct ordering results in properly parsed extra data
contract ExtraDataLibTest is ExtraDataLibTestBase {

    // 1 extra data type
    function test_getExtraData_onlyCommission() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory data = bytes.concat(swapData, commissionData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
        }   
    }

    function test_getExtraData_onlyTrim() public {
        // only trim, trimData length is 64 bytes
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory data = bytes.concat(swapData, trimData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, true);
        // trim and charge, trimData length is 96 bytes
        trimData = _generateTrimDataTrimAndCahrge();
        data = bytes.concat(swapData, trimData);
        extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, false);
    }

    function test_getExtraData_onlyPermit2() public {
        for (uint256 i = 1; i <= 9; i++) {
            // signature65
            bytes memory permit2Data = _generatePermit2Data(i, signature65);
            bytes memory data = bytes.concat(swapData, permit2Data);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            // signature64
            permit2Data = _generatePermit2Data(i, signature64);
            data = bytes.concat(swapData, permit2Data);
            extraData = _callAndDecode(data);
            _assertPermit2Info(extraData.permit2Info, i, signature64);
        }
    }

    function test_getExtraData_onlyRefundTo() public {
        bytes memory refundToData = _generateRefundToData();
        bytes memory data = bytes.concat(swapData, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
    }

    // 2 extra data types
    function test_getExtraData_commissionAndTrim() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            // only trim, trimData length is 64 bytes
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory data = bytes.concat(swapData, trimData, commissionData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
            _assertTrimInfo(extraData.trimInfo, true);
            // trim and charge, trimData length is 96 bytes
            trimData = _generateTrimDataTrimAndCahrge();
            data = bytes.concat(swapData, trimData, commissionData);
            extraData = _callAndDecode(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
            _assertTrimInfo(extraData.trimInfo, false);
        }
    }

    function test_getExtraData_commissionAndPermit2() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                bytes memory commissionData = _generateCommissionData(i);
                // signature65
                bytes memory permit2Data = _generatePermit2Data(j, signature65);
                bytes memory data = bytes.concat(swapData, permit2Data, commissionData);
                IDexRouter.ExtraData memory extraData = _callAndDecode(data);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j, signature65);
                // signature64
                permit2Data = _generatePermit2Data(j, signature64);
                data = bytes.concat(swapData, permit2Data, commissionData);
                extraData = _callAndDecode(data);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j, signature64);
            }
        }
    }

    function test_getExtraData_commissionAndRefundTo() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory refundToData = _generateRefundToData();
            bytes memory data = bytes.concat(swapData, refundToData, commissionData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertCommissionInfo(extraData.commissionInfo, i);
            _assertRefundTo(extraData.refundTo);
        }
    }

    function test_getExtraData_trimAndPermit2() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            // only trim with signature65
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory permit2Data = _generatePermit2Data(i, signature65);
            bytes memory data = bytes.concat(swapData, permit2Data, trimData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            // only trim with signature64
            permit2Data = _generatePermit2Data(i, signature64);
            data = bytes.concat(swapData, permit2Data, trimData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertPermit2Info(extraData.permit2Info, i, signature64);
            // trim and charge with signature65
            trimData = _generateTrimDataTrimAndCahrge();
            permit2Data = _generatePermit2Data(i, signature65);
            data = bytes.concat(swapData, permit2Data, trimData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            // trim and charge with signature64
            permit2Data = _generatePermit2Data(i, signature64);
            data = bytes.concat(swapData, permit2Data, trimData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertPermit2Info(extraData.permit2Info, i, signature64);
        }
    }

    function test_getExtraData_trimAndRefundTo() public {
        // only trim, trimData length is 64 bytes
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory refundToData = _generateRefundToData();
        bytes memory data = bytes.concat(swapData, refundToData, trimData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, true);
        _assertRefundTo(extraData.refundTo);
        // trim and charge, trimData length is 96 bytes
        trimData = _generateTrimDataTrimAndCahrge();
        data = bytes.concat(swapData, refundToData, trimData);
        extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, false);
        _assertRefundTo(extraData.refundTo);
    }

    function test_getExtraData_permit2AndRefundTo() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            bytes memory refundToData = _generateRefundToData();
            // signature65
            bytes memory permit2Data = _generatePermit2Data(i, signature65);
            bytes memory data = bytes.concat(swapData, refundToData, permit2Data);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            _assertRefundTo(extraData.refundTo);
            // signature64
            permit2Data = _generatePermit2Data(i, signature64);
            data = bytes.concat(swapData, refundToData, permit2Data);
            extraData = _callAndDecode(data);
            _assertPermit2Info(extraData.permit2Info, i, signature64);
            _assertRefundTo(extraData.refundTo);
        }
    }

    // 3 extra data types
    function test_getExtraData_commissionAndTrimAndPermit2() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                bytes memory commissionData = _generateCommissionData(i);
                // only trim with signature65
                bytes memory trimData = _generateTrimDataOnlyTrim();
                bytes memory permit2Data = _generatePermit2Data(j, signature65);
                bytes memory data = bytes.concat(swapData, permit2Data, trimData, commissionData);
                IDexRouter.ExtraData memory extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, true);
                _assertPermit2Info(extraData.permit2Info, j, signature65);
                _assertCommissionInfo(extraData.commissionInfo, i);
                // only trim with signature64
                permit2Data = _generatePermit2Data(j, signature64);
                data = bytes.concat(swapData, permit2Data, trimData, commissionData);
                extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, true);
                _assertPermit2Info(extraData.permit2Info, j, signature64);
                _assertCommissionInfo(extraData.commissionInfo, i);
                // trim and charge with signature65
                trimData = _generateTrimDataTrimAndCahrge();
                permit2Data = _generatePermit2Data(j, signature65);
                data = bytes.concat(swapData, permit2Data, trimData, commissionData);
                extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, false);
                _assertPermit2Info(extraData.permit2Info, j, signature65);
                _assertCommissionInfo(extraData.commissionInfo, i);
                // trim and charge with signature64
                permit2Data = _generatePermit2Data(j, signature64);
                data = bytes.concat(swapData, permit2Data, trimData, commissionData);
                extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, false);
                _assertPermit2Info(extraData.permit2Info, j, signature64);
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
            bytes memory data = bytes.concat(swapData, refundToData, trimData, commissionData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertRefundTo(extraData.refundTo);
            _assertCommissionInfo(extraData.commissionInfo, i);
            // trim and charge, trimData length is 96 bytes
            trimData = _generateTrimDataTrimAndCahrge();
            data = bytes.concat(swapData, refundToData, trimData, commissionData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertRefundTo(extraData.refundTo);
            _assertCommissionInfo(extraData.commissionInfo, i);
        }
    }

    function test_getExtraData_commissionAndPermit2AndRefundTo() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                bytes memory commissionData = _generateCommissionData(i);
                bytes memory refundToData = _generateRefundToData();
                // signature65
                bytes memory permit2Data = _generatePermit2Data(j, signature65);
                bytes memory data = bytes.concat(swapData, refundToData, permit2Data, commissionData);
                IDexRouter.ExtraData memory extraData = _callAndDecode(data);
                _assertRefundTo(extraData.refundTo);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j, signature65);
                // signature64
                permit2Data = _generatePermit2Data(j, signature64);
                data = bytes.concat(swapData, refundToData, permit2Data, commissionData);
                extraData = _callAndDecode(data);
                _assertRefundTo(extraData.refundTo);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j, signature64);
            }
        }
    }

    function test_getExtraData_trimAndPermit2AndRefundTo() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            bytes memory refundToData = _generateRefundToData();
            // only trim with signature65
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory permit2Data = _generatePermit2Data(i, signature65);
            bytes memory data = bytes.concat(swapData, refundToData, permit2Data, trimData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            _assertRefundTo(extraData.refundTo);
            // only trim with signature64
            permit2Data = _generatePermit2Data(i, signature64);
            data = bytes.concat(swapData, refundToData, permit2Data, trimData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertPermit2Info(extraData.permit2Info, i, signature64);
            _assertRefundTo(extraData.refundTo);
            // trim and charge with signature65
            trimData = _generateTrimDataTrimAndCahrge();
            permit2Data = _generatePermit2Data(i, signature65);
            data = bytes.concat(swapData, refundToData, permit2Data, trimData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            _assertRefundTo(extraData.refundTo);
            // trim and charge with signature64
            permit2Data = _generatePermit2Data(i, signature64);
            data = bytes.concat(swapData, refundToData, permit2Data, trimData);
            extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, false);
            _assertPermit2Info(extraData.permit2Info, i, signature64);
            _assertRefundTo(extraData.refundTo);
        }
    }

    // 4 extra data types
    function test_getExtraData_all() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            for (uint256 j = 1; j <= permit2AmountsLength; j++) {
                bytes memory commissionData = _generateCommissionData(i);
                bytes memory refundToData = _generateRefundToData();
                // only trim with signature65
                bytes memory trimData = _generateTrimDataOnlyTrim();
                bytes memory permit2Data = _generatePermit2Data(j, signature65);
                bytes memory data = bytes.concat(swapData, refundToData, permit2Data, trimData, commissionData);
                IDexRouter.ExtraData memory extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, true);
                _assertPermit2Info(extraData.permit2Info, j, signature65);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertRefundTo(extraData.refundTo);
                // only trim with signature64
                permit2Data = _generatePermit2Data(j, signature64);
                data = bytes.concat(swapData, refundToData, permit2Data, trimData, commissionData);
                extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, true);
                _assertPermit2Info(extraData.permit2Info, j, signature64);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertRefundTo(extraData.refundTo);
                // trim and charge with signature65
                trimData = _generateTrimDataTrimAndCahrge();
                permit2Data = _generatePermit2Data(j, signature65);
                data = bytes.concat(swapData, refundToData, permit2Data, trimData, commissionData);
                extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, false);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j, signature65);
                _assertRefundTo(extraData.refundTo);
                // trim and charge with signature64
                permit2Data = _generatePermit2Data(j, signature64);
                data = bytes.concat(swapData, refundToData, permit2Data, trimData, commissionData);
                extraData = _callAndDecode(data);
                _assertTrimInfo(extraData.trimInfo, false);
                _assertCommissionInfo(extraData.commissionInfo, i);
                _assertPermit2Info(extraData.permit2Info, j, signature64);
                _assertRefundTo(extraData.refundTo);
            }
        }
    }
}