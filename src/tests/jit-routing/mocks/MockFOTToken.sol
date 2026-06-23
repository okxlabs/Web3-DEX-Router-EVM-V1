// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fee-on-transfer ERC20. On every `transfer` / `transferFrom` a fixed % of the amount is burned.
/// @dev Covers AC-23 / S-20. Fee basis points default 100 = 1%.
contract MockFOTToken is ERC20 {
    uint256 public feeBps;

    constructor(string memory name, string memory symbol, uint256 _feeBps) ERC20(name, symbol) {
        feeBps = _feeBps;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 received = amount - fee;
        if (fee > 0) {
            super._transfer(from, address(0xdead), fee);
        }
        super._transfer(from, to, received);
    }
}
