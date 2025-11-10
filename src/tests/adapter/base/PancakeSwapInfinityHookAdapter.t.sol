// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {PancakeSwapInfinityHookAdapter} from "@dex/adapter/PancakeSwapInfinityHookAdapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {Currency} from "@dex/types/Currency.sol";
import {IVault} from "@dex/interfaces/PancakeSwapInfinity/IVault.sol";

/// @title PancakeSwapInfinityHookAdapterTest
/// @notice Adapter tests for PancakeSwapInfinityHookAdapter
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract PancakeSwapInfinityHookAdapterTest is AbstractAdapterTest {
    
    /// @notice Mapping of network IDs to their wrapped tokens
    mapping(string => address) internal vaults;
    mapping(string => address) internal wrappedTokens;
    mapping(string => address) internal clPoolManagers;
    mapping(string => address) internal binPoolManagers;

    uint256 internal constant BSC_FORK_BLOCK = 63992458; /// @notice constant fork block for BSC to make modifying the code easier
    uint256 internal constant BASE_FORK_BLOCK = 37982605; /// @notice constant fork block for BASE to make modifying the code easier

    /// @notice Create PancakeSwapInfinityHookAdapter for the specified network
    /// @param networkId The network identifier (e.g. "eth", "bsc")
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        // Pool manager addresses per network
        vaults["bsc"] = 0x238a358808379702088667322f80aC48bAd5e6c4;
        wrappedTokens["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        clPoolManagers["bsc"] = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        binPoolManagers["bsc"] = 0xC697d2898e0D09264376196696c51D7aBbbAA4a9;

        // Pool manager addresses per network
        vaults["base"] = 0x238a358808379702088667322f80aC48bAd5e6c4;
        wrappedTokens["base"] = 0x4200000000000000000000000000000000000006;
        clPoolManagers["base"] = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        binPoolManagers["base"] = 0xC697d2898e0D09264376196696c51D7aBbbAA4a9;

        address vault = vaults[networkId];
        address wrappedToken = wrappedTokens[networkId];
        address clPoolManager = clPoolManagers[networkId];
        address binPoolManager = binPoolManagers[networkId];
        require(vault != address(0), "Unsupported network");
        require(wrappedToken != address(0), "Unsupported network");
        require(clPoolManager != address(0), "Unsupported network");
        require(binPoolManager != address(0), "Unsupported network");
        return address(new PancakeSwapInfinityHookAdapter(IVault(vault), wrappedToken, clPoolManager, binPoolManager));
    }

    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        // SwapTestCase[][] memory cases = new SwapTestCase[][](3);
        // cases[0] = getPancakeSwapInfinityBscCLHookTestCases();
        // cases[1] = getPancakeSwapInfinityBscBinNoHookTestCases();
        // cases[2] = getPancakeSwapInfinityBscMultiHopTestCases();

        SwapTestCase[][] memory cases = new SwapTestCase[][](2);
        cases[0] = getPancakeSwapInfinityBaseCLNoHookTestCases();
        cases[1] = getPancakeSwapInfinityBaseBinNoHookTestCases();

        return cases;
    }

    function getPancakeSwapInfinityBscCLHookTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](3);

        address CLPoolManager = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        address BNB = address(0);
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address USDT = 0x55d398326f99059fF775485246999027B3197955;
        address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        address CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

        // BNB -> USDT (CL PoolId: 0x1b13f21c2ec35d30eed8b443c08e5b9db3ae311365a675a5aea5bc44fc27d808)
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys1 = new PancakeSwapInfinityHookAdapter.PathKey[](1);
        pathKeys1[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(BNB),
            outputCurrency: Currency.wrap(USDT),
            poolManager: CLPoolManager,
            fee: 8388608,
            poolParams: 10, // tickSpacing for CL pool
            hook: 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d,
            hookData: ""
        });
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: BSC_FORK_BLOCK,
            fromToken: WBNB,
            toToken: USDT,
            pool: address(0),
            amount: 1000000000000000, // 0.001 BNB
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "BNB to USDT on PancakeSwapInfinity CL hook pool",
            moreInfo: abi.encode(pathKeys1),
            fromTokenPreTo: address(0)
        });

        // USDC -> BNB (CL PoolId: 0xc38e00461a5649e222d41b000698dc8eee20eb8cd7f7efb5bd59115af25f56be)
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys2 = new PancakeSwapInfinityHookAdapter.PathKey[](1);
        pathKeys2[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(USDC),
            outputCurrency: Currency.wrap(BNB),
            poolManager: CLPoolManager,
            fee: 8388608,
            poolParams: 10, // tickSpacing for CL pool
            hook: 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d,
            hookData: ""
        });
        cases[1] = SwapTestCase({
            networkId: "bsc",
            forkBlock: BSC_FORK_BLOCK,
            fromToken: USDC,
            toToken: WBNB,
            pool: address(0),
            amount: 1 * 10 ** 18, // 1 USDC
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "USDC to BNB on PancakeSwapInfinity CL hook pool",
            moreInfo: abi.encode(pathKeys2),
            fromTokenPreTo: address(0)
        });

        // USDT -> Cake (CL PoolId: 0xaf12088595c0d5615f1e9da6033a435705d60037c2a4230dd5e135aab9dcfeb5)
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys3 = new PancakeSwapInfinityHookAdapter.PathKey[](1);
        pathKeys3[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(USDT),
            outputCurrency: Currency.wrap(CAKE),
            poolManager: CLPoolManager,
            fee: 8388608,
            poolParams: 10, // tickSpacing for CL pool
            hook: 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d,
            hookData: ""
        });
        cases[2] = SwapTestCase({
            networkId: "bsc",
            forkBlock: BSC_FORK_BLOCK,
            fromToken: USDT,
            toToken: CAKE,
            pool: address(0),
            amount: 1 * 10 ** 18, // 1 USDT
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "USDT to Cake on PancakeSwapInfinity CL hook pool",
            moreInfo: abi.encode(pathKeys3),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getPancakeSwapInfinityBscBinNoHookTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address BNB = address(0);
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
        address BinPoolManager = 0xC697d2898e0D09264376196696c51D7aBbbAA4a9;

        // BNB -> CAKE (Bin PoolId: 0x1456eb94326c4bc07c73f18fc8b43494a64efa6217867581634802e87d2cab4f)
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys1 = new PancakeSwapInfinityHookAdapter.PathKey[](1);
        pathKeys1[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(BNB),
            outputCurrency: Currency.wrap(CAKE),
            poolManager: BinPoolManager,
            fee: 67,
            poolParams: 1, // binStep for Bin pool
            hook: address(0),
            hookData: ""
        });
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: BSC_FORK_BLOCK,
            fromToken: WBNB,
            toToken: CAKE,
            pool: address(0),
            amount: 0.001 * 10 ** 18,
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "BNB to CAKE on PancakeSwapInfinity Bin no-hook pool",
            moreInfo: abi.encode(pathKeys1),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getPancakeSwapInfinityBscMultiHopTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        address CLPoolManager = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        address BinPoolManager = 0xC697d2898e0D09264376196696c51D7aBbbAA4a9;
        address BNB = address(0);
        address USDT = 0x55d398326f99059fF775485246999027B3197955;
        address USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
        address CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

        // USDC -(CL)-> BNB -(CL)-> USDT
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys1 = new PancakeSwapInfinityHookAdapter.PathKey[](2);
        pathKeys1[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(USDC),
            outputCurrency: Currency.wrap(BNB),
            poolManager: CLPoolManager,
            fee: 8388608,
            poolParams: 10, // tickSpacing for CL pool
            hook: 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d,
            hookData: ""
        });
        pathKeys1[1] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(BNB),
            outputCurrency: Currency.wrap(USDT),
            poolManager: CLPoolManager,
            fee: 8388608,
            poolParams: 10, // tickSpacing for CL pool
            hook: 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d,
            hookData: ""
        });
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: BSC_FORK_BLOCK,
            fromToken: USDC,
            toToken: USDT,
            pool: address(0),
            amount: 1 * 10 ** 18, // 1 USDC
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "Multi-hop swap with only PancakeSwapInfinity CL hook pool",
            moreInfo: abi.encode(pathKeys1),
            fromTokenPreTo: address(0)
        });

        // USDT -(CL)-> BNB -(BIN)-> CAKE
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys2 = new PancakeSwapInfinityHookAdapter.PathKey[](2);
        pathKeys2[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(USDT),
            outputCurrency: Currency.wrap(BNB),
            poolManager: CLPoolManager,
            fee: 8388608,
            poolParams: 10, // tickSpacing for CL pool
            hook: 0x32C59D556B16DB81DFc32525eFb3CB257f7e493d,
            hookData: ""
        });
        pathKeys2[1] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(BNB),
            outputCurrency: Currency.wrap(CAKE),
            poolManager: BinPoolManager,
            fee: 67,
            poolParams: 1, // binStep for Bin pool
            hook: address(0),
            hookData: ""
        });
        cases[1] = SwapTestCase({
            networkId: "bsc",
            forkBlock: BSC_FORK_BLOCK,
            fromToken: USDT,
            toToken: CAKE,
            pool: address(0),
            amount: 1 * 10 ** 18, // 1 USDT
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "Multi-hop swap with PancakeSwapInfinity CL hook and Bin no-hook pools",
            moreInfo: abi.encode(pathKeys2),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getPancakeSwapInfinityBaseCLNoHookTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address CLPoolManager = 0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b;
        address ETH = address(0);
        address WETH = 0x4200000000000000000000000000000000000006;
        address USDT = 0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2;
        address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

        // USDC -> USDT (CL PoolId: 0x5be6d980aeb668a348202d7d2c2fa25ed8d2e83c3b7328f7ef4112cfc3c80a0f)
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys1 = new PancakeSwapInfinityHookAdapter.PathKey[](1);
        pathKeys1[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(USDC),
            outputCurrency: Currency.wrap(USDT),
            poolManager: CLPoolManager,
            fee: 34,
            poolParams: 1, // tickSpacing for CL pool
            hook: address(0),
            hookData: ""
        });
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: BASE_FORK_BLOCK,
            fromToken: USDC,
            toToken: WETH,
            pool: address(0),
            amount: 1 * 10 ** 18, // 1 USDC
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT on PancakeSwapInfinity CL no-hook pool",
            moreInfo: abi.encode(pathKeys1),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getPancakeSwapInfinityBaseBinNoHookTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address ETH = address(0);
        address WETH = 0x4200000000000000000000000000000000000006;
        address CBETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
        address BinPoolManager = 0xC697d2898e0D09264376196696c51D7aBbbAA4a9;

        // ETH -> CBETH (Bin PoolId: 0x3e46b3dc482fc0f761d941e492bcbfaa3e9e4f58e22daf90968b9f2f4bfd589a)
        PancakeSwapInfinityHookAdapter.PathKey[] memory pathKeys1 = new PancakeSwapInfinityHookAdapter.PathKey[](1);
        pathKeys1[0] = PancakeSwapInfinityHookAdapter.PathKey({
            inputCurrency: Currency.wrap(ETH),
            outputCurrency: Currency.wrap(CBETH),
            poolManager: BinPoolManager,
            fee: 54,
            poolParams: 1, // binStep for Bin pool
            hook: address(0),
            hookData: ""
        });
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: BASE_FORK_BLOCK,
            fromToken: WETH,
            toToken: CBETH,
            pool: address(0),
            amount: 0.001 * 10 ** 18,
            expectedOutput: 0, // dynamic output
            sellBase: true,
            expectRevert: false,
            description: "ETH to CBETH on PancakeSwapInfinity Bin no-hook pool",
            moreInfo: abi.encode(pathKeys1),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}