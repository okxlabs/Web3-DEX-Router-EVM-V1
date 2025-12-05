// // SPDX-License-Identifier: SEE LICENSE IN LICENSE
// pragma solidity ^0.8.0;

// import {PMMAdapter, IPMMProtocol} from "@dex/adapter/PmmAdapter.sol";
// import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

// /// @title PmmAdapter
// /// @notice Adapter tests for PmmAdapter
// /// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
// contract PmmAdapterTest is AbstractAdapterTest {
//     /**
//      * @dev Create PmmAdapter
//      */
//     function createCustomAdapter(
//         string memory /* networkId */
//     ) internal override returns (address) {
//         return address(new PMMAdapter());
//     }

//     /**
//      * @dev Define test cases for PmmAdapter swaps
//      */
//     function getSwapTestCases()
//         internal
//         override
//         pure
//         returns (SwapTestCase[][] memory)
//     {
//         SwapTestCase[][] memory cases = new SwapTestCase[][](1);
//         cases[0] = getPmmTestCases();

//         return cases;
//     }

//     function getPmmTestCases()
//         internal
//         pure
//         returns (SwapTestCase[] memory)
//     {
//         // Token addresses on Base network
//         address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
//         address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

//         address RFQPool = 0x8C3D3bbE4D5a41349Db248fc2436442d4968Cb7b;
//         SwapTestCase[] memory cases = new SwapTestCase[](1);

//         // Test 1: USDT to USDC
//         // tx: https://arbiscan.io/tx/0xed4ac7aa0f1a0d4e173649bb33b2844d47b92dbb71f6d99cb3b9e52f735c8ea5
//         bytes memory SIGNATURE = hex"ff4cad1f96187ddb47102dd2b800150e8533b0d0f009e86474fcbd3576d07afa4b89d3028bc23781416b1573282552c35f8462923550599724cb2fd2e85d79751c";
//         IPMMProtocol.OrderRFQ memory order = IPMMProtocol.OrderRFQ({
//             rfqId: 13578,
//             expiry: 2068195245,
//             makerAsset: USDC,
//             takerAsset: USDT,
//             makerAddress: 0x80C0664922CF70a9c38e131861403c428F36C035,
//             makerAmount: 101000,
//             takerAmount: 100000,
//             usePermit2: true
//         });

//         cases[0] = SwapTestCase({
//             networkId: "arb",
//             forkBlock: 358280378,
//             fromToken: USDT,
//             toToken: USDC,
//             pool: RFQPool,
//             amount: 100000, // 0.1 USDT
//             expectedOutput: 101000, // 0.101 USDC
//             sellBase: true,
//             expectRevert: false,
//             description: "USDT to USDC on Arbitrum RFQ",
//             moreInfo: abi.encode(order, SIGNATURE, 0),
//             fromTokenPreTo: address(0)
//         });

//         return cases;
//     }
// }