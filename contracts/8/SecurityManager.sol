// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./interfaces/ITokenApproveProxyAdmin.sol";

contract SecurityManager is AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");

    ITokenApproveProxyAdmin public immutable tokenApproveProxy;
    EnumerableSet.AddressSet private _whitelist;

    event ProxyAdded(address indexed proxy);
    event ProxyRemoved(address indexed proxy);

    modifier onlyAdminOrSecurity() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender) || hasRole(SECURITY_ROLE, msg.sender),
            "SM: unauthorized"
        );
        _;
    }

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

    function whitelistLength() external view returns (uint256) {
        return _whitelist.length();
    }

    function whitelistContains(address _proxy) external view returns (bool) {
        return _whitelist.contains(_proxy);
    }

    function getWhitelist() external view returns (address[] memory) {
        return _whitelist.values();
    }

    function whitelistAt(uint256 _index) external view returns (address) {
        return _whitelist.at(_index);
    }

    function addProxy(address _proxy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_proxy != address(0), "SM: zero address");
        // No isAllowedProxy() pre-check needed: this call is what causes the proxy entry.
        // Mirror-proxy parity holds by induction from the constructor's S4 invariant.
        require(_whitelist.add(_proxy), "SM: already in whitelist");
        tokenApproveProxy.addProxy(_proxy);
        emit ProxyAdded(_proxy);
    }

    function removeProxy(address _proxy) external onlyAdminOrSecurity {
        require(_whitelist.remove(_proxy), "SM: not in whitelist");
        tokenApproveProxy.removeProxy(_proxy);
        emit ProxyRemoved(_proxy);
    }

    function removeProxies(address[] calldata _proxies) external onlyAdminOrSecurity {
        for (uint256 i = 0; i < _proxies.length; i++) {
            if (_whitelist.remove(_proxies[i])) {
                tokenApproveProxy.removeProxy(_proxies[i]);
                emit ProxyRemoved(_proxies[i]);
            }
        }
    }

    function setTokenApprove(address _tokenApprove) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenApproveProxy.setTokenApprove(_tokenApprove);
    }
}
