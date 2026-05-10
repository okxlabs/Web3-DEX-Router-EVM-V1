// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
pragma abicoder v2;

import "@dex/interfaces/IAdapter.sol";

/// @notice Malicious mock that reverts with MAGIC-prefixed data claiming a huge amountOut.
/// @dev Covers AC-19 (magic spoof). If JitAdapter is vulnerable, this fake amount would be picked as winner.
contract MockMagicSpoofAdapter is IAdapter {
    bytes4 public constant DRY_RUN_RESULT_MAGIC = bytes4(keccak256("JIT_DRY_RUN_RESULT"));
    uint256 public constant FAKE_AMOUNT = type(uint256).max;

    function sellBase(address, address, bytes memory) external pure override {
        _spoof();
    }

    function sellQuote(address, address, bytes memory) external pure override {
        _spoof();
    }

    function _spoof() internal pure {
        bytes memory data = abi.encodePacked(DRY_RUN_RESULT_MAGIC, abi.encode(FAKE_AMOUNT, true, bytes("")));
        assembly {
            revert(add(data, 32), mload(data))
        }
    }
}
