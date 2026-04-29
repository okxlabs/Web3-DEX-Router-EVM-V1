// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable func-name-mixedcase

import "forge-std/Test.sol";
import "@dex/SecurityManager.sol";
import "@dex/TokenApproveProxy.sol";

contract SecurityManagerTest is Test {
    TokenApproveProxy oldProxy;
    SecurityManager sm;

    address constant MULTISIG = address(0xA1);
    address constant SECURITY_CO = address(0xB1);
    address constant DEX_ROUTER = address(0xCAFE);
    address constant XBRIDGE = address(0xBEEF);

    function setUp() public virtual {
        oldProxy = new TokenApproveProxy();
        oldProxy.initialize();
        oldProxy.addProxy(DEX_ROUTER);
        oldProxy.addProxy(XBRIDGE);

        address[] memory initial = new address[](2);
        initial[0] = DEX_ROUTER;
        initial[1] = XBRIDGE;
        sm = new SecurityManager(address(oldProxy), MULTISIG, initial);

        oldProxy.transferOwnership(address(sm));
    }

    function test_Constructor_StoresProxyAddress() public {
        assertEq(address(sm.tokenApproveProxy()), address(oldProxy));
    }

    function test_Constructor_GrantsAdminRole() public {
        assertTrue(sm.hasRole(sm.DEFAULT_ADMIN_ROLE(), MULTISIG));
    }

    function test_Constructor_InitializesWhitelistMirror() public {
        assertEq(sm.whitelistLength(), 2);
        assertTrue(sm.whitelistContains(DEX_ROUTER));
        assertTrue(sm.whitelistContains(XBRIDGE));
    }

    function test_Constructor_RevertsOnZeroProxy() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(bytes("SM: zero proxy"));
        new SecurityManager(address(0), MULTISIG, empty);
    }

    function test_Constructor_RevertsOnZeroAdmin() public {
        address[] memory empty = new address[](0);
        vm.expectRevert(bytes("SM: zero admin"));
        new SecurityManager(address(oldProxy), address(0), empty);
    }

    function test_Constructor_RevertsOnZeroInInitialWhitelist() public {
        address[] memory initial = new address[](2);
        initial[0] = DEX_ROUTER;
        initial[1] = address(0);
        vm.expectRevert(bytes("SM: zero in initial"));
        new SecurityManager(address(oldProxy), MULTISIG, initial);
    }

    function test_Constructor_RevertsIfNotAllowedOnProxy() public {
        // 0xCAFE is on the proxy (added in setUp); 0xDEAD is not.
        address[] memory initial = new address[](2);
        initial[0] = DEX_ROUTER;
        initial[1] = address(0xDEAD);
        vm.expectRevert(bytes("SM: not allowed on proxy"));
        new SecurityManager(address(oldProxy), MULTISIG, initial);
    }
}
