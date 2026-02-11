/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./CommonLib.sol";
import "../interfaces/IDexRouter.sol";

library TrimLib {
    function validateTrimInfo(IDexRouter.TrimInfo memory trimInfo) internal pure {
        if (!trimInfo.hasTrim) return;

        // Validate trim/charge recipient addresses to prevent accidental burns.
        if (trimInfo.chargeRate < TRIM_DENOMINATOR) { // Not all trim is charged, so trimAddress should not be zero
            require(trimInfo.trimAddress != address(0), "Invalid trimAddress");
        }
        if (trimInfo.chargeRate > 0) {
            require(trimInfo.chargeAddress != address(0), "Invalid chargeAddress");
        }
    }
}