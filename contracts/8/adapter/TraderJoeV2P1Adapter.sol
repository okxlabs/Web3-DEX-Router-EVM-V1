// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "../interfaces/IAdapter.sol";
import "../interfaces/ITraderJoeV2P1.sol";

contract TraderJoeV2P1Adapter is IAdapter {
    
    function _traderJoeV2P1Swap(
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
        _traderJoeV2P1Swap(to, pool, moreInfo);
    }

    // fromToken == tokenY
    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _traderJoeV2P1Swap(to, pool, moreInfo);
    }
}
