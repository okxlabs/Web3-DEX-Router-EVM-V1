// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Ekubo Config type - address (20 bytes) | fee (8 bytes) | tickSpacing (4 bytes)
type Config is bytes32;

// Ekubo PoolKey structure
struct PoolKey {
    address token0;
    address token1;
    Config config;
}

// PoolKey helper functions
library PoolKeyLibrary {
    function tickSpacing(PoolKey memory pk) internal pure returns (uint32 r) {
        assembly ("memory-safe") {
            r := and(mload(add(64, pk)), 0xffffffff)
        }
    }

    function fee(PoolKey memory pk) internal pure returns (uint64 r) {
        assembly ("memory-safe") {
            r := and(mload(add(60, pk)), 0xffffffffffffffff)
        }
    }

    function extension(PoolKey memory pk) internal pure returns (address r) {
        assembly ("memory-safe") {
            r := and(mload(add(52, pk)), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }

    // Construct Config
    function toConfig(uint64 _fee, uint32 _tickSpacing, address _extension) internal pure returns (Config c) {
        assembly ("memory-safe") {
            c := add(add(shl(96, _extension), shl(32, _fee)), _tickSpacing)
        }
    }

    // Calculate poolId
    function toPoolId(PoolKey memory key) internal pure returns (bytes32 result) {
        assembly ("memory-safe") {
            // Perform keccak256 hash on the entire PoolKey structure
            result := keccak256(key, 96)  // 20 + 20 + 32 = 72 bytes, but official code uses 96
        }
    }
}

// Ekubo Core interface
interface IEkuboCore {
    function lock() external;
    
    function swap_611415377(
        PoolKey memory poolKey,
        int128 amount,
        bool isToken1,
        uint96 sqrtRatioLimit,
        uint256 skipAhead
    ) external payable returns (int128 delta0, int128 delta1);
    
    function clear(address token) external returns (uint256 paid);
    
    function withdraw(address token, address to, uint128 amount) external;
    
    function pay(address token) external returns (uint128 payment);
    
    // Get pool state
    function poolState(bytes32 poolId) external view returns (
        uint160 sqrtRatio,
        int24 tick,
        uint128 liquidity
    );
}

// Ekubo Locker callback interface
interface IEkuboLocker {
    function locked(uint256 id) external returns (bytes memory);
    
    function payCallback(uint256 id, address token) external;
}