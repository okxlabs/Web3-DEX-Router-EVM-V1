// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {fraxETHAdapter} from "@dex/adapter/fraxETHAdapter.sol";

contract fraxETHAdapterTest is AbstractAdapterTest {

    // Mapping of network IDs to their Frax ETH addresses
    mapping(string => FraxETHConfig) internal fraxETHConfigs;

    struct FraxETHConfig {
        address weth;
        address frxETHMinter;
        address sfrxETH;
        address frxETH;
    }

    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // Frax ETH addresses per network
        fraxETHConfigs["eth"] = FraxETHConfig({
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // Ethereum WETH
            frxETHMinter: 0xbAFA44EFE7901E04E39Dad13167D089C559c1138, // frxETHMinter
            // sfrxETH: 0xac3E018457B222d93114458476f3E3416Abbe38F, // sfrxETH
            sfrxETH: 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497, // Staked USDe
            // frxETH: 0x5E8422345238F34275888049021821E8E08CAa1f // frxETH
            frxETH: 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3 // USDe
        });

        FraxETHConfig memory config = fraxETHConfigs[networkId];
        require(config.weth != address(0), "Unsupported network for Frax ETH");
        require(config.frxETHMinter != address(0), "Frax ETH not deployed on this network");
        
        return address(new fraxETHAdapter(
            config.weth,
            config.frxETHMinter,
            config.sfrxETH,
            config.frxETH
        ));
    }

    function getSwapTestCases()
        internal
        override
        pure
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](1);
        cases[0] = getStakedUSDestCases();

        return cases;
    }

    function getStakedUSDestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        // Token addresses on Ethereum mainnet
        address USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
        address StakedUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

        // Test case based on transaction: 0x885fb0adf697a851509ea10dac40a2fcc373f2dbf6f116699febc447fbdecbaa
        // ETH to frxETH conversion
        cases[0] = SwapTestCase({
            networkId: "eth",
            forkBlock: 23378221, 
            fromToken: USDe, 
            toToken: StakedUSDe, // frxETH as output
            pool: address(0), // Not used in fraxETH adapter
            amount: 36805.65 * 10 ** 18, // 1 ETH worth of WETH
            expectedOutput: 30746306491739392601756, // Dynamic output based on current exchange rate
            sellBase: true,
            expectRevert: false,
            description: "USDe to StakedUSDe conversion via Frax ETH Minter",
            moreInfo: abi.encode(fraxETHAdapter.SWAPTYPE.FRXETH_TO_SFRXETH), // SWAPTYPE.ETH_TO_FRXETH
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    
}
