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
    function getExtraData() public pure returns (ExtraData memory) {
        return getDecodedExtraData();
    }
}

contract ExtraDataLibTest is Test, CommissionHelper, TrimHelper, Permit2Helper {
    ExtraDataLibTestHelper extraDataLibTestHelper;

    address public token = makeAddr("token");
    address[] public referrerAddresses = new address[](8);
    uint256[] public commissionRates = new uint256[](8);
    address public trimAddress = makeAddr("trimAddress");
    address public chargeAddress = makeAddr("chargeAddress");
    address public refundTo = makeAddr("refundTo");

    constructor() {
        for (uint256 i = 0; i < 8; i++) {
            referrerAddresses[i] = makeAddr(string(abi.encodePacked("referrerAddress", i)));
            commissionRates[i] = i * 100000;
        }
    }

    function setUp() public {
        extraDataLibTestHelper = new ExtraDataLibTestHelper();
    }

    // 1 extra data type
    function test_getExtraData_onlyCommission() public {

    }

    function test_getExtraData_onlyTrim() public {

    }

    function test_getExtraData_onlyPermit2() public {

    }

    function test_getExtraData_onlyRefundTo() public {

    }

    // 2 extra data types
    function test_getExtraData_commissionAndTrim() public {

    }

    function test_getExtraData_commissionAndPermit2() public {
    }

    function test_getExtraData_commissionAndRefundTo() public {
    }

    function test_getExtraData_trimAndPermit2() public {
    }
    function test_getExtraData_trimAndRefundTo() public {
    }
    function test_getExtraData_permit2AndRefundTo() public {
    }

    // 3 extra data types
    function test_getExtraData_commissionAndTrimAndPermit2() public {
    }

    function test_getExtraData_commissionAndTrimAndRefundTo() public {
    }

    function test_getExtraData_commissionAndPermit2AndRefundTo() public {
    }

    function test_getExtraData_trimAndPermit2AndRefundTo() public {
    }

    // 4 extra data types
    function test_getExtraData_all() public {
    }

    // ==================== Internal functions ====================
    function _generateRefundToData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(REFUND_TO_ADDRESS_FLAG | uint256(uint160(refundTo))));
    }

    function _generateCommissionData() internal view returns (bytes memory) {
        return _buildCommissionInfoUnified(
            true, // isFromTokenCommission
            false, // isToTokenCommission
            token, // token
            true, // isToBCommission
            commissionRates,
            referrerAddresses
        );
    }
}