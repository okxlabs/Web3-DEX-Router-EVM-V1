/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";
import "./CommonLib.sol";
import "../interfaces/IDexRouter.sol";

library TrimLib {
    function validateTrimInfo(IDexRouter.TrimInfo memory trimInfo) internal pure {
        if (!trimInfo.hasTrim) return;

        // Validate trimRate and chargeRate
        require(trimInfo.trimRate <= TRIM_RATE_LIMIT, "error trim rate");
        require(trimInfo.chargeRate <= TRIM_DENOMINATOR_1E3, "error charge rate");

        // Validate trim/charge recipient addresses to prevent accidental burns.
        if (trimInfo.chargeRate < TRIM_DENOMINATOR_1E3) { // Not all trim is charged, so trimAddress should not be zero
            require(trimInfo.trimAddress != address(0), "Invalid trimAddress");
        }
        if (trimInfo.chargeRate > 0) {
            require(trimInfo.chargeAddress != address(0), "Invalid chargeAddress");
        }
    }
}