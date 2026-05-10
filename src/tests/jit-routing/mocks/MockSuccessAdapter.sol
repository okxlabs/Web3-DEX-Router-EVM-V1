// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";
import "@dex/interfaces/IERC20.sol";
import "@dex/libraries/SafeERC20.sol";

/// @notice Mock adapter that transfers a pre-configured amountOut of toToken to `to`.
/// @dev extraData = abi.encode(address toToken, uint256 amountOut).
///      Pre-fund the mock adapter with `toToken` before use.
///      Requires `assetTo == address(mockSuccessAdapter)` in Candidate (JitAdapter transfers fromToken to adapter itself).
contract MockSuccessAdapter is IAdapter {
    function sellBase(
        address to,
        address,
        /*pool*/
        bytes memory data
    )
        external
        override
    {
        _execute(to, data);
    }

    function sellQuote(
        address to,
        address,
        /*pool*/
        bytes memory data
    )
        external
        override
    {
        _execute(to, data);
    }

    function _execute(address to, bytes memory data) internal {
        (address toToken, uint256 amountOut) = abi.decode(data, (address, uint256));
        SafeERC20.safeTransfer(IERC20(toToken), to, amountOut);
    }
}
