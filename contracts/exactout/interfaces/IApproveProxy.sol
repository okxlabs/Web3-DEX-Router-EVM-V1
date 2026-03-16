// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IApproveProxy {
    function isAllowedProxy(address _proxy) external view returns (bool);

    function claimTokens(
        address token,
        address who,
        address dest,
        uint256 amount
    ) external;

    function tokenApprove() external view returns (address);
    function addProxy(address) external;
}
