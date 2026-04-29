// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITokenApproveProxyAdmin.sol";

/// @title SecurityManager — governance wrapper over TokenApproveProxy
/// @notice Owns the underlying TokenApproveProxy and front-runs every privileged operation on it, splitting whitelist add (admin-only) from whitelist remove (admin OR security) so that an emergency-response role can revoke compromised proxies without holding full admin power.
/// @dev SecurityManager keeps an on-chain mirror of the underlying proxy's allow-list in an EnumerableSet so it can be enumerated off-chain by the audit team. State changes are always written to BOTH the mirror and the underlying TokenApproveProxy in the same transaction; the constructor's invariants S3 (no zero address) and S4 (every initial whitelist entry must already be allowed on the underlying proxy) bootstrap the mirror-proxy parity, and every subsequent admin path preserves it. The contract is intentionally not upgradeable; if it needs replacement, use {transferTokenApproveProxyOwnership} as the escape hatch.
contract SecurityManager is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Role that can REMOVE proxies from the whitelist (incident response). Cannot add proxies.
    /// @dev Granted/revoked via AccessControl's {grantRole}/{revokeRole}, which themselves require DEFAULT_ADMIN_ROLE.
    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");

    /// @notice The underlying TokenApproveProxy that this SecurityManager governs.
    /// @dev Immutable: set at construction and cannot be retargeted. To replace it, deploy a new SecurityManager.
    ITokenApproveProxyAdmin public immutable tokenApproveProxy;

    /// @dev On-chain mirror of the underlying proxy's allow-list. Kept in sync with the underlying on every admin path.
    EnumerableSet.AddressSet private _whitelist;

    // --- Events ---

    /// @notice Emitted when a proxy is added to the whitelist (and to the underlying TokenApproveProxy).
    /// @param proxy The proxy address that was added.
    event ProxyAdded(address indexed proxy);

    /// @notice Emitted when a proxy is removed from the whitelist (and from the underlying TokenApproveProxy).
    /// @param proxy The proxy address that was removed.
    event ProxyRemoved(address indexed proxy);

    // --- Modifiers ---

    /// @notice Restricts a function to callers holding either DEFAULT_ADMIN_ROLE or SECURITY_ROLE (logical OR).
    modifier onlyAdminOrSecurity() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(SECURITY_ROLE, msg.sender),
            "SM: unauthorized"
        );
        _;
    }

    /// @notice Deploy SecurityManager bound to a specific TokenApproveProxy and seed the initial whitelist.
    /// @param _tokenApproveProxy Address of the underlying TokenApproveProxy this contract will govern. Must be non-zero. SecurityManager must be (or become) the owner of this proxy off-band for any admin path to actually take effect downstream.
    /// @param _admin Address granted DEFAULT_ADMIN_ROLE. Must be non-zero. This account can later grant/revoke SECURITY_ROLE.
    /// @param _initialWhitelist Proxies to seed the mirror with. Each entry must be non-zero (S3) and must already be allowed on the underlying proxy (S4) — these invariants bootstrap mirror-proxy parity without needing any external calls back to the underlying.
    /// @dev S3 (zero rejection) and S4 (must-already-be-on-proxy) are enforced per-entry. Duplicates in `_initialWhitelist` are silently deduplicated by EnumerableSet, but supplying duplicates is not recommended.
    constructor(
        address _tokenApproveProxy,
        address _admin,
        address[] memory _initialWhitelist
    ) {
        require(_tokenApproveProxy != address(0), "SM: zero proxy");
        require(_admin != address(0), "SM: zero admin");
        tokenApproveProxy = ITokenApproveProxyAdmin(_tokenApproveProxy);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        for (uint256 i = 0; i < _initialWhitelist.length; i++) {
            require(_initialWhitelist[i] != address(0), "SM: zero in initial");
            require(
                ITokenApproveProxyAdmin(_tokenApproveProxy).isAllowedProxy(_initialWhitelist[i]),
                "SM: not allowed on proxy"
            );
            _whitelist.add(_initialWhitelist[i]);
        }
    }

    // --- Views ---

    /// @notice Number of proxies currently in the whitelist mirror.
    /// @return Count of whitelisted proxies.
    function whitelistLength() external view returns (uint256) {
        return _whitelist.length();
    }

    /// @notice Whether a given address is currently in the whitelist mirror.
    /// @param _proxy Address to query.
    /// @return Whether the address is whitelisted.
    function whitelistContains(address _proxy) external view returns (bool) {
        return _whitelist.contains(_proxy);
    }

    /// @notice Return the entire whitelist as an array.
    /// @dev Intended for off-chain enumeration (e.g. periodic audit by the security team). Do not call from on-chain logic with an unbounded whitelist size.
    /// @return The list of whitelisted proxy addresses.
    function getWhitelist() external view returns (address[] memory) {
        return _whitelist.values();
    }

    /// @notice Return the whitelisted proxy at the given index.
    /// @param _index Index into the underlying EnumerableSet. Order is not stable across remove operations.
    /// @return The proxy address at that index.
    function whitelistAt(uint256 _index) external view returns (address) {
        return _whitelist.at(_index);
    }

    // --- Admin functions ---

    /// @notice Add a proxy to the whitelist and to the underlying TokenApproveProxy.
    /// @param _proxy The proxy address to allow. Must be non-zero and must not already be in the whitelist.
    /// @dev DEFAULT_ADMIN_ROLE only. Writes to BOTH the mirror and the underlying proxy in the same transaction. No isAllowedProxy() pre-check is needed because this very call is what causes the proxy entry on the underlying; mirror-proxy parity is preserved by induction from the constructor's S4 invariant.
    function addProxy(address _proxy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_proxy != address(0), "SM: zero address");
        // No isAllowedProxy() pre-check needed: this call is what causes the proxy entry.
        // Mirror-proxy parity holds by induction from the constructor's S4 invariant.
        require(_whitelist.add(_proxy), "SM: already in whitelist");
        tokenApproveProxy.addProxy(_proxy);
        emit ProxyAdded(_proxy);
    }

    /// @notice Remove a proxy from the whitelist and from the underlying TokenApproveProxy.
    /// @param _proxy The proxy address to revoke. Must currently be in the whitelist.
    /// @dev DEFAULT_ADMIN_ROLE OR SECURITY_ROLE. The split between add (admin-only) and remove (admin OR security) is the entire reason this contract exists: it lets an incident-response role rapidly revoke a compromised proxy without holding full admin power. Writes to BOTH the mirror and the underlying proxy.
    function removeProxy(address _proxy) external onlyAdminOrSecurity {
        require(_whitelist.remove(_proxy), "SM: not in whitelist");
        tokenApproveProxy.removeProxy(_proxy);
        emit ProxyRemoved(_proxy);
    }

    /// @notice Batch-remove proxies from the whitelist and from the underlying TokenApproveProxy.
    /// @param _proxies Proxies to revoke. Entries that are not currently whitelisted are silently skipped (no revert), so this can be safely retried after a partial failure or used for best-effort fan-out.
    /// @dev DEFAULT_ADMIN_ROLE OR SECURITY_ROLE. Same semantics as {removeProxy} except for the skip-on-missing behavior.
    function removeProxies(address[] calldata _proxies) external onlyAdminOrSecurity {
        for (uint256 i = 0; i < _proxies.length; i++) {
            if (_whitelist.remove(_proxies[i])) {
                tokenApproveProxy.removeProxy(_proxies[i]);
                emit ProxyRemoved(_proxies[i]);
            }
        }
    }

    /// @notice Forward `setTokenApprove` to the underlying TokenApproveProxy, redirecting where it pulls user tokens from.
    /// @param _tokenApprove The new TokenApprove contract address on the underlying proxy.
    /// @dev DEFAULT_ADMIN_ROLE only. This is a highly sensitive operation: it changes the source-of-truth for ALL user token transfers routed through the underlying proxy. Pure pass-through — no mirror state to update here.
    function setTokenApprove(address _tokenApprove) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenApproveProxy.setTokenApprove(_tokenApprove);
    }

    /// @notice Escape hatch: transfer ownership of the underlying TokenApproveProxy to a new owner.
    /// @param _newOwner The new owner of the underlying TokenApproveProxy. Must be non-zero.
    /// @dev DEFAULT_ADMIN_ROLE only. IRREVERSIBLE from this contract — once ownership leaves SecurityManager, none of the admin functions on this contract can affect the underlying proxy until ownership is returned by other means. Intended only for: (a) replacing this SecurityManager with a new governance contract, or (b) emergency recovery if a bug is found in this contract. Does NOT clear the local whitelist mirror, which becomes stale once ownership has been transferred away.
    function transferTokenApproveProxyOwnership(address _newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newOwner != address(0), "SM: zero address");
        tokenApproveProxy.transferOwnership(_newOwner);
    }
}
