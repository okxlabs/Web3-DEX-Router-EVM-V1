// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable func-name-mixedcase

import "forge-std/Test.sol";
import "@dex/SecurityManager.sol";
import "@dex/TokenApproveProxy.sol";

contract SecurityManagerTest is Test {
    event ProxyAdded(address indexed proxy);
    event ProxyRemoved(address indexed proxy);

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

    function test_AddProxy_ByAdmin_AddsToMirrorAndProxy() public {
        address newProxy = address(0xD1);
        vm.prank(MULTISIG);
        sm.addProxy(newProxy);

        assertTrue(sm.whitelistContains(newProxy));
        assertTrue(oldProxy.isAllowedProxy(newProxy));
    }

    function test_AddProxy_EmitsEvent() public {
        address newProxy = address(0xD2);
        vm.expectEmit(true, false, false, true);
        emit ProxyAdded(newProxy);
        vm.prank(MULTISIG);
        sm.addProxy(newProxy);
    }

    function test_AddProxy_ByNonAdmin_Reverts() public {
        address attacker = address(0xDEAD);
        vm.expectRevert();
        vm.prank(attacker);
        sm.addProxy(address(0xD3));
    }

    function test_AddProxy_BySecurityRole_Reverts() public {
        // Cache the role getter before vm.prank: the getter is the next external call
        // and would otherwise consume the prank, leaving grantRole to run as the test contract.
        bytes32 securityRole = sm.SECURITY_ROLE();
        vm.prank(MULTISIG);
        sm.grantRole(securityRole, SECURITY_CO);

        vm.expectRevert();
        vm.prank(SECURITY_CO);
        sm.addProxy(address(0xD4));
    }

    function test_AddProxy_Duplicate_Reverts() public {
        vm.prank(MULTISIG);
        vm.expectRevert(bytes("SM: already in whitelist"));
        sm.addProxy(DEX_ROUTER);
    }

    function test_AddProxy_ZeroAddress_Reverts() public {
        vm.prank(MULTISIG);
        vm.expectRevert(bytes("SM: zero address"));
        sm.addProxy(address(0));
    }

    function _grantSecurityRole() internal {
        // Cache the role getter before vm.prank: the getter is the next external call
        // and would otherwise consume the prank, leaving grantRole to run as the test contract.
        bytes32 securityRole = sm.SECURITY_ROLE();
        vm.prank(MULTISIG);
        sm.grantRole(securityRole, SECURITY_CO);
    }

    function test_RemoveProxy_ByAdmin() public {
        vm.prank(MULTISIG);
        sm.removeProxy(DEX_ROUTER);
        assertFalse(sm.whitelistContains(DEX_ROUTER));
        assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));
    }

    function test_RemoveProxy_BySecurityRole() public {
        _grantSecurityRole();
        vm.prank(SECURITY_CO);
        sm.removeProxy(DEX_ROUTER);
        assertFalse(sm.whitelistContains(DEX_ROUTER));
        assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));
    }

    function test_RemoveProxy_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ProxyRemoved(DEX_ROUTER);
        vm.prank(MULTISIG);
        sm.removeProxy(DEX_ROUTER);
    }

    function test_RemoveProxy_ByRandomEOA_Reverts() public {
        vm.expectRevert(bytes("SM: unauthorized"));
        vm.prank(address(0xDEAD));
        sm.removeProxy(DEX_ROUTER);
    }

    function test_RemoveProxy_NotInWhitelist_Reverts() public {
        vm.prank(MULTISIG);
        vm.expectRevert(bytes("SM: not in whitelist"));
        sm.removeProxy(address(0xDEAD));
    }

    function test_RemoveProxy_AfterRevoke_Reverts() public {
        _grantSecurityRole();
        // Cache the role getter before vm.prank for the same reason as in _grantSecurityRole.
        bytes32 securityRole = sm.SECURITY_ROLE();
        vm.prank(MULTISIG);
        sm.revokeRole(securityRole, SECURITY_CO);

        vm.expectRevert(bytes("SM: unauthorized"));
        vm.prank(SECURITY_CO);
        sm.removeProxy(DEX_ROUTER);
    }

    function test_RemoveProxies_ByAdmin_RemovesAll() public {
        address[] memory list = new address[](2);
        list[0] = DEX_ROUTER;
        list[1] = XBRIDGE;

        vm.prank(MULTISIG);
        sm.removeProxies(list);

        assertFalse(sm.whitelistContains(DEX_ROUTER));
        assertFalse(sm.whitelistContains(XBRIDGE));
        assertEq(sm.whitelistLength(), 0);
    }

    function test_RemoveProxies_BySecurityRole() public {
        _grantSecurityRole();
        address[] memory list = new address[](2);
        list[0] = DEX_ROUTER;
        list[1] = XBRIDGE;

        vm.prank(SECURITY_CO);
        sm.removeProxies(list);

        assertEq(sm.whitelistLength(), 0);
        assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));
        assertFalse(oldProxy.isAllowedProxy(XBRIDGE));
    }

    function test_RemoveProxies_SkipsNonExistent() public {
        address[] memory list = new address[](3);
        list[0] = DEX_ROUTER;
        list[1] = address(0xDEAD); // not in whitelist
        list[2] = XBRIDGE;

        vm.recordLogs();
        vm.prank(MULTISIG);
        sm.removeProxies(list); // should not revert

        assertEq(sm.whitelistLength(), 0);

        // Verify ONLY DEX_ROUTER and XBRIDGE produced ProxyRemoved events;
        // address(0xDEAD) was skipped and must NOT appear.
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sig = keccak256("ProxyRemoved(address)");
        uint256 emittedCount = 0;
        bool sawDexRouter = false;
        bool sawXbridge = false;
        bool sawDead = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == sig) {
                emittedCount++;
                address indexedAddr = address(uint160(uint256(entries[i].topics[1])));
                if (indexedAddr == DEX_ROUTER) sawDexRouter = true;
                if (indexedAddr == XBRIDGE) sawXbridge = true;
                if (indexedAddr == address(0xDEAD)) sawDead = true;
            }
        }
        assertEq(emittedCount, 2, "expected exactly 2 ProxyRemoved events");
        assertTrue(sawDexRouter, "DEX_ROUTER event missing");
        assertTrue(sawXbridge, "XBRIDGE event missing");
        assertFalse(sawDead, "0xDEAD must not produce ProxyRemoved event");
    }

    function test_RemoveProxies_ByRandomEOA_Reverts() public {
        address[] memory list = new address[](1);
        list[0] = DEX_ROUTER;

        vm.expectRevert(bytes("SM: unauthorized"));
        vm.prank(address(0xDEAD));
        sm.removeProxies(list);
    }

    function test_RemoveProxies_EmitsEventPerRemoval() public {
        address[] memory list = new address[](2);
        list[0] = DEX_ROUTER;
        list[1] = XBRIDGE;

        // Lock in the per-proxy event semantics. If a future change collapses these
        // into a single batch event, this test will catch it.
        vm.expectEmit(true, false, false, true);
        emit ProxyRemoved(DEX_ROUTER);
        vm.expectEmit(true, false, false, true);
        emit ProxyRemoved(XBRIDGE);

        vm.prank(MULTISIG);
        sm.removeProxies(list);
    }

    function test_GetWhitelist_ReturnsAll() public {
        address[] memory list = sm.getWhitelist();
        assertEq(list.length, 2);
        // EnumerableSet 不保证顺序，使用 contains 校验
        assertTrue(sm.whitelistContains(list[0]));
        assertTrue(sm.whitelistContains(list[1]));
    }

    function test_WhitelistAt_ReturnsAddressByIndex() public {
        address a0 = sm.whitelistAt(0);
        address a1 = sm.whitelistAt(1);
        assertTrue(a0 == DEX_ROUTER || a0 == XBRIDGE);
        assertTrue(a1 == DEX_ROUTER || a1 == XBRIDGE);
        assertTrue(a0 != a1);
    }

    function test_WhitelistAt_OutOfBounds_Reverts() public {
        vm.expectRevert();
        sm.whitelistAt(99);
    }

    function test_SetTokenApprove_ByAdmin() public {
        address newTokenApprove = address(0xE1);
        vm.prank(MULTISIG);
        sm.setTokenApprove(newTokenApprove);
        assertEq(oldProxy.tokenApprove(), newTokenApprove);
    }

    function test_SetTokenApprove_BySecurityRole_Reverts() public {
        _grantSecurityRole();
        vm.expectRevert();
        vm.prank(SECURITY_CO);
        sm.setTokenApprove(address(0xE2));
    }

    function test_SetTokenApprove_ByRandomEOA_Reverts() public {
        vm.expectRevert();
        vm.prank(address(0xDEAD));
        sm.setTokenApprove(address(0xE3));
    }

    function test_TransferProxyOwnership_ByAdmin() public {
        address newOwner = address(0xF1);
        vm.prank(MULTISIG);
        sm.transferTokenApproveProxyOwnership(newOwner);
        assertEq(oldProxy.owner(), newOwner);
    }

    function test_TransferProxyOwnership_BySecurityRole_Reverts() public {
        _grantSecurityRole();
        vm.expectRevert();
        vm.prank(SECURITY_CO);
        sm.transferTokenApproveProxyOwnership(address(0xF2));
    }

    function test_TransferProxyOwnership_ZeroAddress_Reverts() public {
        vm.prank(MULTISIG);
        vm.expectRevert(bytes("SM: zero address"));
        sm.transferTokenApproveProxyOwnership(address(0));
    }
}
