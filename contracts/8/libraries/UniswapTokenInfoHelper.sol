/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../libraries/Constants.sol";
import {IUni} from "../interfaces/IUni.sol";
import {IUniV3} from "../interfaces/IUniV3.sol";

/// @title UniswapTokenInfoHelper
/// @notice Helper functions for getting fromToken and toToken from
/// encoded pools array of unxswap and uniswapV3Swap methods.
/// @dev This contract will be used in DexRouter. So the
/// masks are re-defined here and keep the same as in the original contracts.
library UniswapTokenInfoHelper {
    function getUnxswapTokenInfo(bool sendValue, bytes32[] calldata pools)
        internal
        view
        returns (address fromToken, address toToken)
    {
        require(pools.length > 0, "pools must be greater than 0");

        // get fromToken
        address firstPoolAddr = address(uint160(uint256(pools[0]) & _ADDRESS_MASK));
        // default: token0 to token1; reverse: token1 to token0
        bool firstReversed = (uint256(pools[0]) & _REVERSE_MASK) != 0;
        fromToken = firstReversed ? IUni(firstPoolAddr).token1() : IUni(firstPoolAddr).token0();
        if (fromToken == _WETH && sendValue) {
            fromToken = _ETH;
        }
        require(!sendValue || fromToken == _ETH, "msg.value should be zero");

        // get toToken
        bytes32 lastPool = pools[pools.length - 1];
        address lastPoolAddr = address(uint160(uint256(lastPool) & _ADDRESS_MASK));
        bool lastReversed = (uint256(lastPool) & _REVERSE_MASK) != 0;
        toToken = lastReversed ? IUni(lastPoolAddr).token0() : IUni(lastPoolAddr).token1();
        bool isWeth = (uint256(lastPool) & _WETH_MASK) != 0; // unwrap weth to eth eventually
        if (toToken == _WETH && isWeth) {
            toToken = _ETH;
        }
    }


    function getUniswapV3TokenInfo(bool sendValue, uint256[] calldata pools)
        internal
        view
        returns (address fromToken, address toToken)
    {
        require(pools.length > 0, "pools must be greater than 0");

        // get fromToken
        address firstPoolAddr = address(uint160(pools[0] & _ADDRESS_MASK));
        bool firstZeroForOne = (pools[0] & _ONE_FOR_ZERO_MASK) == 0;
        fromToken = firstZeroForOne ? IUniV3(firstPoolAddr).token0() : IUniV3(firstPoolAddr).token1();
        if (fromToken == _WETH && sendValue) {
            fromToken = _ETH;
        }
        require(!sendValue || fromToken == _ETH, "msg.value should be zero");

        // get toToken
        uint256 lastPool = pools[pools.length - 1];
        address lastPoolAddr = address(uint160(lastPool & _ADDRESS_MASK));
        bool lastZeroForOne = (lastPool & _ONE_FOR_ZERO_MASK) == 0;
        toToken = lastZeroForOne ? IUniV3(lastPoolAddr).token1() : IUniV3(lastPoolAddr).token0();
        bool unwrapWeth = (lastPool & _WETH_UNWRAP_MASK) != 0; // unwrap weth to eth eventually
        if (toToken == _WETH && unwrapWeth) {
            toToken = _ETH;
        }
    }
}