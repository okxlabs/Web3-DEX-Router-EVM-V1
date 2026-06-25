// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// solhint-disable func-name-mixedcase

import "forge-std/Test.sol";
import "@dex/SecurityManager.sol";
import "@dex/TokenApproveProxy.sol";

contract SecurityManagerTest is Test {
    event ProxyAdded(address indexed proxy, address indexed operator);
    event ProxyRemoved(address indexed proxy, address indexed operator);
    event TokenApproveChanged(address newTokenApprove);

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

    function test_Constructor_RevertsOnDuplicateInInitialWhitelist() public {
        address[] memory dup = new address[](3);
        dup[0] = DEX_ROUTER;
        dup[1] = XBRIDGE;
        dup[2] = DEX_ROUTER; // duplicate of dup[0]
        vm.expectRevert(bytes("SM: dup in initial"));
        new SecurityManager(address(oldProxy), MULTISIG, dup);
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
        vm.expectEmit(true, true, false, true);
        emit ProxyAdded(newProxy, MULTISIG);
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
        vm.expectEmit(true, true, false, true);
        emit ProxyRemoved(DEX_ROUTER, MULTISIG);
        vm.prank(MULTISIG);
        sm.removeProxy(DEX_ROUTER);
    }

    function test_RemoveProxy_BySecurityRole_EmitsWithSecurityOperator() public {
        // The operator field is the entire point of adding it to the event: it lets
        // audit dashboards distinguish "planned admin cleanup" from "emergency security
        // revocation". If this attribution is ever broken (e.g. someone hardcodes
        // MULTISIG into the emit), this test catches it.
        _grantSecurityRole();
        vm.expectEmit(true, true, false, true);
        emit ProxyRemoved(DEX_ROUTER, SECURITY_CO);
        vm.prank(SECURITY_CO);
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

    function _deployFreshSmWithGhost() internal returns (TokenApproveProxy ghostProxy, SecurityManager ghostSm, address ghost) {
        // Build a deployment where the underlying proxy has 3 entries but SM is seeded with only 2.
        // The third entry (ghost) is on the underlying but NOT in SM's mirror — exactly the
        // scenario Finding 1 is designed to recover from.
        ghostProxy = new TokenApproveProxy();
        ghostProxy.initialize();
        ghostProxy.addProxy(DEX_ROUTER);
        ghostProxy.addProxy(XBRIDGE);
        ghost = address(0x1337);
        ghostProxy.addProxy(ghost);

        address[] memory seed = new address[](2);
        seed[0] = DEX_ROUTER;
        seed[1] = XBRIDGE;
        ghostSm = new SecurityManager(address(ghostProxy), MULTISIG, seed);
        ghostProxy.transferOwnership(address(ghostSm));
    }

    function test_RemoveProxy_GhostOnProxyOnly_BySecurityRole_Succeeds() public {
        (TokenApproveProxy ghostProxy, SecurityManager ghostSm, address ghost) = _deployFreshSmWithGhost();
        bytes32 securityRole = ghostSm.SECURITY_ROLE();
        vm.prank(MULTISIG);
        ghostSm.grantRole(securityRole, SECURITY_CO);

        // Ghost was never in the mirror, but IS on the underlying. Security firm must be able to revoke it.
        vm.prank(SECURITY_CO);
        ghostSm.removeProxy(ghost);

        assertFalse(ghostProxy.isAllowedProxy(ghost), "ghost still on underlying");
        assertFalse(ghostSm.whitelistContains(ghost), "mirror should not contain ghost");
    }

    function test_RemoveProxy_GhostOnProxyOnly_ByAdmin_Succeeds() public {
        (TokenApproveProxy ghostProxy, SecurityManager ghostSm, address ghost) = _deployFreshSmWithGhost();
        vm.prank(MULTISIG);
        ghostSm.removeProxy(ghost);
        assertFalse(ghostProxy.isAllowedProxy(ghost));
    }

    function test_RemoveProxies_GhostOnProxy_RemovesGhost() public {
        (TokenApproveProxy ghostProxy, SecurityManager ghostSm, address ghost) = _deployFreshSmWithGhost();
        address[] memory list = new address[](2);
        list[0] = DEX_ROUTER; // in mirror AND on proxy
        list[1] = ghost;       // ghost: on proxy only

        vm.prank(MULTISIG);
        ghostSm.removeProxies(list);

        assertFalse(ghostProxy.isAllowedProxy(DEX_ROUTER));
        assertFalse(ghostProxy.isAllowedProxy(ghost), "ghost not removed in batch");
        assertEq(ghostSm.whitelistLength(), 1, "only XBRIDGE should remain in mirror");
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
        // address(0xDEAD) was skipped and must NOT appear. Also verify the operator
        // topic (topic[2]) is the actual caller, locking in the attribution semantics.
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sig = keccak256("ProxyRemoved(address,address)");
        uint256 emittedCount = 0;
        bool sawDexRouter = false;
        bool sawXbridge = false;
        bool sawDead = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && entries[i].topics[0] == sig) {
                emittedCount++;
                address indexedAddr = address(uint160(uint256(entries[i].topics[1])));
                address operator = address(uint160(uint256(entries[i].topics[2])));
                assertEq(operator, MULTISIG, "operator topic must be the caller");
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
        // into a single batch event, this test will catch it. Also locks in the
        // operator attribution: msg.sender on the entry call is propagated to each emit.
        vm.expectEmit(true, true, false, true);
        emit ProxyRemoved(DEX_ROUTER, MULTISIG);
        vm.expectEmit(true, true, false, true);
        emit ProxyRemoved(XBRIDGE, MULTISIG);

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

    function test_SetTokenApprove_ZeroAddress_Reverts() public {
        vm.prank(MULTISIG);
        vm.expectRevert(bytes("SM: zero address"));
        sm.setTokenApprove(address(0));
    }

    function test_SetTokenApprove_EmitsUnderlyingEvent() public {
        address newTokenApprove = address(0xE9);
        // The underlying TokenApproveProxy emits TokenApproveChanged when setTokenApprove succeeds.
        // SM does not emit its own event; we lock the delegation contract here.
        vm.expectEmit(false, false, false, true, address(oldProxy));
        emit TokenApproveChanged(newTokenApprove);
        vm.prank(MULTISIG);
        sm.setTokenApprove(newTokenApprove);
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

    function test_TransferProxyOwnership_PreventsLaterAdminCalls() public {
        address newOwner = address(0xF9);
        vm.prank(MULTISIG);
        sm.transferTokenApproveProxyOwnership(newOwner);

        // After ownership has moved away, SM is no longer the owner of the underlying proxy,
        // so any pass-through admin call must revert at the underlying's onlyOwner check.
        vm.prank(MULTISIG);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        sm.addProxy(address(0xAB));
    }

    function test_Integration_AddRemoveAddSequence() public {
        address proxyAddr = address(0xAA);

        vm.prank(MULTISIG);
        sm.addProxy(proxyAddr);
        assertTrue(oldProxy.isAllowedProxy(proxyAddr));

        vm.prank(MULTISIG);
        sm.removeProxy(proxyAddr);
        assertFalse(oldProxy.isAllowedProxy(proxyAddr));

        vm.prank(MULTISIG);
        sm.addProxy(proxyAddr); // should succeed again
        assertTrue(oldProxy.isAllowedProxy(proxyAddr));
    }

    function test_Integration_MirrorAndProxyStayInSync() public {
        // 任意一组操作后，镜像与老 Proxy 状态都必须一致
        address[] memory pool = new address[](3);
        pool[0] = address(0xA1A1);
        pool[1] = address(0xA2A2);
        pool[2] = address(0xA3A3);

        vm.startPrank(MULTISIG);
        sm.addProxy(pool[0]);
        sm.addProxy(pool[1]);
        sm.addProxy(pool[2]);

        address[] memory removeList = new address[](2);
        removeList[0] = pool[0];
        removeList[1] = DEX_ROUTER;
        sm.removeProxies(removeList);
        vm.stopPrank();

        address[] memory mirror = sm.getWhitelist();
        for (uint256 i = 0; i < mirror.length; i++) {
            assertTrue(oldProxy.isAllowedProxy(mirror[i]), "mirror leak");
        }
        // 镜像之外应不在老 Proxy
        assertFalse(oldProxy.isAllowedProxy(pool[0]));
        assertFalse(oldProxy.isAllowedProxy(DEX_ROUTER));

        // Length invariant: started with {DEX_ROUTER, XBRIDGE} = 2, added pool[0..2] = +3 → 5,
        // then removeProxies removed {pool[0], DEX_ROUTER} = -2 → 3.
        assertEq(mirror.length, 3);

        // Reverse-direction parity: every survivor on the proxy must also be on the mirror.
        // (We can't iterate the proxy mapping, but we can pin specific known survivors.)
        assertTrue(oldProxy.isAllowedProxy(XBRIDGE));
        assertTrue(oldProxy.isAllowedProxy(pool[1]));
        assertTrue(oldProxy.isAllowedProxy(pool[2]));
        assertTrue(sm.whitelistContains(XBRIDGE));
        assertTrue(sm.whitelistContains(pool[1]));
        assertTrue(sm.whitelistContains(pool[2]));
    }

    function test_GetWhitelist_EmptyAfterRemoveAll() public {
        address[] memory list = new address[](2);
        list[0] = DEX_ROUTER;
        list[1] = XBRIDGE;
        vm.prank(MULTISIG);
        sm.removeProxies(list);

        assertEq(sm.whitelistLength(), 0);
        assertEq(sm.getWhitelist().length, 0);
        vm.expectRevert();
        sm.whitelistAt(0);
    }

    function test_Empty_InitialWhitelist_Works() public {
        TokenApproveProxy freshProxy = new TokenApproveProxy();
        freshProxy.initialize();
        address[] memory empty = new address[](0);
        SecurityManager freshSm = new SecurityManager(address(freshProxy), MULTISIG, empty);
        assertEq(freshSm.whitelistLength(), 0);
    }
}
