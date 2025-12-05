pragma solidity ^0.8.0;
pragma abicoder v2;

import {IUniswapV2Pair} from "./IUniswapV2Pair.sol";

interface IDyorPumpRouterV3 {

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable  ;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address payer,
        address to,
        address team,
        uint256 teamRatePercent,
        uint deadline
    ) external ;
}

interface IDyorPoolV3 {
    function getVirtualReserves() external view returns (uint112 reserve0, uint112 reserve1);
    
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external;
    
    function token0() external view returns (address);
    function token1() external view returns (address);
}