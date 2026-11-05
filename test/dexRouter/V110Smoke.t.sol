// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "@dex/DexRouter.sol";

contract V110SmokeTest is Test {
    function testVersionAndOwner() public {
        DexRouter router = new DexRouter(address(this));

        assertEq(router.version(), "v1.0.10-rfq-anti-arbitrage");
        assertEq(router.owner(), address(this));
    }
}
