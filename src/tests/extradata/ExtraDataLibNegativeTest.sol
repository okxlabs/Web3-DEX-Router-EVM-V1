// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExtraDataLibTestBase.t.sol";

/// @title ExtraDataLibNegativeTest
/// @notice Test cases for unexpected/incorrect calldata concatenation order
/// @dev The correct order should be: swapData + refundToData + permit2Data + trimData + commissionData
///      These tests verify that incorrect ordering results in empty/invalid parsed data
contract ExtraDataLibNegativeTest is ExtraDataLibTestBase {

    // ==================== 2 extra data types (wrong order) ====================

    /// @notice Test: commission data placed before trim data (wrong order)
    /// @dev Correct order: trimData + commissionData
    ///      Wrong order: commissionData + trimData
    function test_wrongOrder_commissionBeforeTrim() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        // Wrong order: commission before trim
        bytes memory data = bytes.concat(swapData, commissionData, trimData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, true);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: commission data placed before permit2 data (wrong order)
    /// @dev Correct order: permit2Data + commissionData
    ///      Wrong order: commissionData + permit2Data
    function test_wrongOrder_commissionBeforePermit2() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        // Wrong order: commission before permit2
        bytes memory data = bytes.concat(swapData, commissionData, permit2Data);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: commission data placed before permit2 data with signature64 (wrong order)
    function test_wrongOrder_commissionBeforePermit2_sig64() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory permit2Data = _generatePermit2Data(1, signature64);
        // Wrong order: commission before permit2
        bytes memory data = bytes.concat(swapData, commissionData, permit2Data);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertPermit2Info(extraData.permit2Info, 1, signature64);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: commission data placed before refundTo data (wrong order)
    /// @dev Correct order: refundToData + commissionData
    ///      Wrong order: commissionData + refundToData
    function test_wrongOrder_commissionBeforeRefundTo() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory refundToData = _generateRefundToData();
        // Wrong order: commission before refundTo
        bytes memory data = bytes.concat(swapData, commissionData, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: trim data placed before permit2 data (wrong order)
    /// @dev Correct order: permit2Data + trimData
    ///      Wrong order: trimData + permit2Data
    function test_wrongOrder_trimBeforePermit2() public {
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        // Wrong order: trim before permit2
        bytes memory data = bytes.concat(swapData, trimData, permit2Data);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
    }

    /// @notice Test: trim and charge data placed before permit2 data (wrong order)
    function test_wrongOrder_trimAndChargeBeforePermit2() public {
        bytes memory trimData = _generateTrimDataTrimAndCahrge();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        // Wrong order: trim before permit2
        bytes memory data = bytes.concat(swapData, trimData, permit2Data);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
    }

    /// @notice Test: refundTo data placed after trim data (wrong order)
    /// @dev Correct order: refundToData + trimData
    ///      Wrong order: trimData + refundToData
    function test_wrongOrder_refundToAfterTrim() public {
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory refundToData = _generateRefundToData();
        // Wrong order: trim before refundTo
        bytes memory data = bytes.concat(swapData, trimData, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
    }

    /// @notice Test: refundTo data placed after permit2 data (wrong order)
    /// @dev Correct order: refundToData + permit2Data
    ///      Wrong order: permit2Data + refundToData
    function test_wrongOrder_refundToAfterPermit2() public {
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        bytes memory refundToData = _generateRefundToData();
        // Wrong order: permit2 before refundTo
        bytes memory data = bytes.concat(swapData, permit2Data, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertPermit2InfoBeEmpty(extraData.permit2Info);
    }

    /// @notice Test: wrong order with multiple commission referrers (2 types)
    function test_wrongOrder_multipleReferrers_commissionBeforeTrim() public {
        for (uint256 i = 1; i <= commissionReferrerNum; i++) {
            bytes memory commissionData = _generateCommissionData(i);
            bytes memory trimData = _generateTrimDataOnlyTrim();
            // Wrong order: commission before trim
            bytes memory data = bytes.concat(swapData, commissionData, trimData);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertTrimInfo(extraData.trimInfo, true);
            _assertCommissionInfoBeEmpty(extraData.commissionInfo);
        }
    }

    /// @notice Test: wrong order with different permit2 amounts (2 types)
    function test_wrongOrder_differentPermit2Amounts_trimBeforePermit2() public {
        for (uint256 i = 1; i <= permit2AmountsLength; i++) {
            bytes memory trimData = _generateTrimDataOnlyTrim();
            bytes memory permit2Data = _generatePermit2Data(i, signature65);
            // Wrong order: trim before permit2
            bytes memory data = bytes.concat(swapData, trimData, permit2Data);
            IDexRouter.ExtraData memory extraData = _callAndDecode(data);
            _assertPermit2Info(extraData.permit2Info, i, signature65);
            _assertTrimInfoBeEmpty(extraData.trimInfo);
        }
    }

    // ==================== 3 extra data types (wrong order) ====================

    /// @notice Test: commission and trim swapped in 3-data combination
    /// @dev Correct order: permit2Data + trimData + commissionData
    ///      Wrong order: permit2Data + commissionData + trimData
    function test_wrongOrder_commissionAndTrimSwapped() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        // Wrong: commission and trim swapped
        bytes memory data = bytes.concat(swapData, permit2Data, commissionData, trimData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, true);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
        _assertPermit2InfoBeEmpty(extraData.permit2Info);
    }

    /// @notice Test: permit2 placed after trim and commission (3 types)
    /// @dev Correct order: permit2Data + trimData + commissionData
    ///      Wrong order: trimData + commissionData + permit2Data
    function test_wrongOrder_permit2AtEnd() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        // Wrong: permit2 at the end
        bytes memory data = bytes.concat(swapData, trimData, commissionData, permit2Data);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
    }

    /// @notice Test: refundTo placed after trim and commission (3 types)
    /// @dev Correct order: refundToData + trimData + commissionData
    ///      Wrong order: trimData + commissionData + refundToData
    function test_wrongOrder_refundToAtEnd_3types() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory refundToData = _generateRefundToData();
        // Wrong: refundTo at the end
        bytes memory data = bytes.concat(swapData, trimData, commissionData, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
    }

    /// @notice Test: permit2 and trim swapped with refundTo (3 types)
    /// @dev Correct order: refundToData + permit2Data + trimData
    ///      Wrong order: refundToData + trimData + permit2Data
    function test_wrongOrder_permit2AndTrimSwapped_withRefundTo() public {
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        bytes memory refundToData = _generateRefundToData();
        // Wrong: permit2 and trim swapped
        bytes memory data = bytes.concat(swapData, refundToData, trimData, permit2Data);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
        _assertRefundToBeEmpty(extraData.refundTo);

    }

    // ==================== 4 extra data types (wrong order - all types) ====================

    /// @notice Test: all extra data in completely reversed order
    /// @dev Correct order: refundToData + permit2Data + trimData + commissionData
    ///      Wrong order: commissionData + trimData + permit2Data + refundToData
    function test_wrongOrder_allReversed() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        bytes memory refundToData = _generateRefundToData();
        // Completely reversed order
        bytes memory data = bytes.concat(swapData, commissionData, trimData, permit2Data, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertPermit2InfoBeEmpty(extraData.permit2Info);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: all extra data in completely reversed order with signature64
    function test_wrongOrder_allReversed_sig64() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature64);
        bytes memory refundToData = _generateRefundToData();
        // Completely reversed order
        bytes memory data = bytes.concat(swapData, commissionData, trimData, permit2Data, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertPermit2InfoBeEmpty(extraData.permit2Info);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: commission placed at the beginning (4 types)
    /// @dev Correct order: refundToData + permit2Data + trimData + commissionData
    ///      Wrong order: commissionData + refundToData + permit2Data + trimData
    function test_wrongOrder_commissionAtBeginning() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        bytes memory refundToData = _generateRefundToData();
        // Wrong: commission at the beginning
        bytes memory data = bytes.concat(swapData, commissionData, refundToData, permit2Data, trimData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertTrimInfo(extraData.trimInfo, true);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertRefundTo(extraData.refundTo);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
    }

    /// @notice Test: permit2 and trim swapped (4 types)
    /// @dev Correct order: refundToData + permit2Data + trimData + commissionData
    ///      Wrong order: refundToData + trimData + permit2Data + commissionData
    function test_wrongOrder_permit2AndTrimSwapped_allTypes() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        bytes memory refundToData = _generateRefundToData();
        // Wrong: permit2 and trim swapped
        bytes memory data = bytes.concat(swapData, refundToData, trimData, permit2Data, commissionData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertCommissionInfo(extraData.commissionInfo, 1);
        _assertPermit2Info(extraData.permit2Info, 1, signature65);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
        _assertRefundToBeEmpty(extraData.refundTo);
    }

    /// @notice Test: refundTo placed at the end (4 types)
    /// @dev Correct order: refundToData + permit2Data + trimData + commissionData
    ///      Wrong order: permit2Data + trimData + commissionData + refundToData
    function test_wrongOrder_refundToAtEnd_allTypes() public {
        bytes memory commissionData = _generateCommissionData(1);
        bytes memory trimData = _generateTrimDataOnlyTrim();
        bytes memory permit2Data = _generatePermit2Data(1, signature65);
        bytes memory refundToData = _generateRefundToData();
        // Wrong: refundTo at the end
        bytes memory data = bytes.concat(swapData, permit2Data, trimData, commissionData, refundToData);
        IDexRouter.ExtraData memory extraData = _callAndDecode(data);
        _assertRefundTo(extraData.refundTo);
        _assertCommissionInfoBeEmpty(extraData.commissionInfo);
        _assertTrimInfoBeEmpty(extraData.trimInfo);
        _assertPermit2InfoBeEmpty(extraData.permit2Info);
    }
}
