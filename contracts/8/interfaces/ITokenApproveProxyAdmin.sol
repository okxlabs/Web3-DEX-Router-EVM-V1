// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITokenApproveProxyAdmin {
    function addProxy(address _newProxy) external;
    function removeProxy(address _oldProxy) external;
    function setTokenApprove(address _tokenApprove) external;
    function transferOwnership(address newOwner) external;
    function isAllowedProxy(address _proxy) external view returns (bool);
    function tokenApprove() external view returns (address);
    function owner() external view returns (address);
}
