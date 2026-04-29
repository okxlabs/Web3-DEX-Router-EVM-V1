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
}
