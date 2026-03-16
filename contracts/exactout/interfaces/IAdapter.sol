/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

interface IAdapter {
    function sellBase(
        address to,
        address pool,
        bytes memory data
    ) external;

    function sellQuote(
        address to,
        address pool,
        bytes memory data
    ) external;
}
