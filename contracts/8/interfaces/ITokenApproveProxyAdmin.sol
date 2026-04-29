// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Management-plane interface for TokenApproveProxy
/// @notice Exposes only the admin/owner-side surface of TokenApproveProxy that SecurityManager needs to govern it.
/// @dev This is the management-plane counterpart to {IApproveProxy} (which is the runtime/claim-plane). SecurityManager interacts with the underlying TokenApproveProxy exclusively through this interface. Keeping these two interfaces separate prevents SecurityManager from being granted any runtime token-claim ability by mistake.
interface ITokenApproveProxyAdmin {
    /// @notice Add a proxy address to the underlying TokenApproveProxy's allow-list. Owner-only on the underlying.
    /// @param _newProxy The proxy address to allow.
    function addProxy(address _newProxy) external;

    /// @notice Remove a proxy address from the underlying TokenApproveProxy's allow-list. Owner-only on the underlying.
    /// @param _oldProxy The proxy address to revoke.
    function removeProxy(address _oldProxy) external;

    /// @notice Update the TokenApprove contract that the underlying proxy delegates token transfers to. Owner-only on the underlying.
    /// @param _tokenApprove The new TokenApprove contract address.
    function setTokenApprove(address _tokenApprove) external;

    /// @notice Transfer ownership of the underlying TokenApproveProxy. Owner-only on the underlying.
    /// @param newOwner The new owner address.
    function transferOwnership(address newOwner) external;

    /// @notice View whether an address is currently allowed on the underlying TokenApproveProxy.
    /// @param _proxy The proxy address to query.
    /// @return Whether the address is allowed on the underlying proxy.
    function isAllowedProxy(address _proxy) external view returns (bool);

    /// @notice Read the TokenApprove contract address currently configured on the underlying proxy.
    /// @return The TokenApprove contract address.
    function tokenApprove() external view returns (address);

    /// @notice Read the current owner of the underlying TokenApproveProxy.
    /// @return The owner address.
    function owner() external view returns (address);
}
