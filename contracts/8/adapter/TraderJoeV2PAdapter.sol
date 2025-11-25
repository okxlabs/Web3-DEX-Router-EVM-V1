// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/ITraderJoeV2P.sol";

/// @title TraderJoe (V2.1 & V2.2) Adapter
/// @notice Unified adapter for TraderJoe V2.1 and V2.2 pools
/// @dev Both versions use identical swap interface, can share the same adapter
contract TraderJoeV2PAdapter is IAdapter {
    
    function _traderJoeV2PSwap(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {
        (address tokenIn) = abi.decode(moreInfo, (address));
        address tokenX = address(ILBPair(pool).getTokenX());  
        ILBPair(pool).swap(tokenIn == tokenX, to);
    }
    
    // fromToken == tokenX
    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _traderJoeV2PSwap(to, pool, moreInfo);
    }

    // fromToken == tokenY
    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _traderJoeV2PSwap(to, pool, moreInfo);
    }
}

