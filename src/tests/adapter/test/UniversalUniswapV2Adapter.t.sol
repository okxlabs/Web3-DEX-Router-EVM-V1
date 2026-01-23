// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {UniversalUniswapV2Adapter} from "@dex/adapter/TemplateAdapter/UniversalUniswapV2Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/**
 * @title UniversalUniswapV2AdapterTest
 * @dev Simple test for UniversalUniswapV2Adapter
 * @dev UniversalUniswapV2Adapter uses 0.2% fee (998/1000)
 * @dev Uses "bsc" network identifier from foundry.toml
 */
contract UniversalUniswapV2AdapterTest is AbstractAdapterTest {
    /**
     * @dev Create ApeSwap adapter
     */
    function createCustomAdapter(string memory /* networkId */) internal override returns (address) {
        return address(new UniversalUniswapV2Adapter());
    }

    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](10);
        cases[0] = getApeSwapV2TestCases();
        cases[1] = getRDexV2TestCases();
        cases[2] = getLynexTestCases();
        cases[3] = getDyorLaunchedTestCases();
        cases[4] = getEtherexClassicTestCases();
        cases[5] = getDooarTestCases();
        cases[6] = getCronaSwapTestCases();
        cases[7] = getAVAXTestCase();
        cases[8] = getInSwapTestCases();
        cases[9] = getMonadJoeTestCases();

        return cases;
    }

    function getInSwapTestCases() internal pure returns (SwapTestCase[] memory) {

        address INS = 0x3099ba1C5018FA015230F47ceD588f20D4B20000;
        address WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;

        address pool = 0x6e94C8B63BcE20C911E37bedb7D9A357f8AB3A4A;
        SwapTestCase[] memory cases = new SwapTestCase[](2);
        // https://www.oklink.com/zh-hans/x-layer/tx/0xa407577a825a4b7945731735985912349c1dcf223d1652d933f0408bee977c57
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 42860621 - 1,
            fromToken: INS,
            toToken: WOKB,
            pool: pool,
            amount: 52407640217778534158649,
            expectedOutput: 995008294477516994,
            sellBase: true,
            expectRevert: false,
            description: "INS to WOKB on XLayer",
            moreInfo: abi.encode(9975, 10000),
            fromTokenPreTo: address(0)
        });

        address VALUE = 0xD938D723E758b6F4BC3C84e8eD78Cb10Af7f0000;
        address pool2 = 0x8a54F70CE3f38D485235d8f05f9eB6829BDFf101;
        //https://www.oklink.com/zh-hans/x-layer/tx/0x46a25460116a69544ca68fba6717416e7bde2bc007c4d4b15e17327c0aee07c4
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 42864619,
            fromToken: VALUE,
            toToken: WOKB,
            pool: pool2,
            amount: 206183337205649775700712,
            expectedOutput: 1431732787618451694,
            sellBase: true,
            expectRevert: false,
            description: "VALUE to WOKB on XLayer",
            moreInfo: abi.encode(9975, 10000),
            fromTokenPreTo: address(0)
        });
        return cases;
    }

    function getCronaSwapTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address WCRO = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;
        address USDC = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
        address WCRO_USDC_POOL = 0x0625A68D25d304aed698c806267a4e369e8Eb12a;
        //https://cronoscan.com/tx/0xb03977728411444ed8c22f408bff62cd07f7a0c8abe67ca773abe0732511fd1f
        cases[0] = SwapTestCase({
            networkId: "cro",
            forkBlock: 32185138 - 1,
            fromToken: WCRO,
            toToken: USDC,
            pool: WCRO_USDC_POOL,
            amount: 170 ether,
            expectedOutput: 38.409408 * 10 ** 6,
            sellBase: true,
            expectRevert: false,
            description: "WCRO to USDC on CronaSwap",
            moreInfo: abi.encode(9975, 10000),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getDooarTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        address WPOL = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address USDT0 = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        address WPOL_USDT0_POOL = 0xC84F479bF220E38BA3bd0262049BAd47Aaa673EE;
        //https://polygonscan.com/tx/0x6c930723fd10d55d74b4702ae82c9158f7eb371f3f817691fc69b4618ab87698
        cases[0] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 76521141 - 1,
            fromToken: WPOL,
            toToken: USDT0,
            pool: WPOL_USDT0_POOL,
            amount: 827.531418609526541691 * 10 ** 18,
            expectedOutput: 210149562,
            sellBase: true,
            expectRevert: false,
            description: "WPOL to USDT0 on Polygon",
            moreInfo: abi.encode(990, 1000),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    ///@notice not correct, need to be fixed, output amount is not correct
    function getEtherexClassicTestCases() internal pure returns (SwapTestCase[] memory) {

        address USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
        address USDT = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;
        address USDC_USDT_POOL = 0x8418e91cf8Cbf7Dd37B6492e23Bec75D0F4D81D8;
        bytes memory etherexClassicFee = abi.encode(10000, 10000);
        //https://lineascan.build/tx/0x12f577c0b75c2588210bcace8c28f09c0a8a3d54db80cfb2f63738e0392726dc
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        cases[0] = SwapTestCase({
            networkId: "linea",
            forkBlock: 23384001 - 1,
            fromToken: USDC,
            toToken: USDT,
            pool: USDC_USDT_POOL,
            amount: 8500.00108 * 10 ** 6,
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "USDC to USDT on Etherex Classic",
            moreInfo: etherexClassicFee,
            fromTokenPreTo: address(0)
        });
        return cases;
    }

    function getDyorLaunchedTestCases() internal pure returns (SwapTestCase[] memory) {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // X Layer token addresses - need to be determined from the actual transaction
        address pandas = 0xa3e4378dFA9577c5533d8bbf3E65f79C05304A36; // From address as placeholder
        address wokb = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // To address as placeholder  
        address pandas_wokb_pool = 0x08cD095Ff9769cFA8316e169Eda51a9536FAa9d9; // Interaction address from transaction
        
        // UniV2 standard fee (0.3%)
        bytes memory uniV2Fee = abi.encode(9975, 10000);
        
        // https://www.oklink.com/zh-hans/x-layer/tx/0xa259948a5c619008327993b4c9cf9d3452a8cd0c1663771734bf7cd0b49156a4
        cases[0] = SwapTestCase({
            networkId: "xlayer", // X Layer network
            forkBlock: 31216141 - 1, // Block number from transaction minus 1
            fromToken: pandas,
            toToken: wokb,
            pool: pandas_wokb_pool,
            amount: 5181098730924224163434824,
            expectedOutput: 2802506141882401960, // actual output in tx is 2801142742387142461, but the actual
            sellBase: true,
            expectRevert: false,
            description: "Pandas to WOKB on XLayer via DyorLaunched", 
            moreInfo: uniV2Fee,
            fromTokenPreTo: address(0)
        });
        return cases;
    }
    /**
     * @dev Define test cases for ApeSwap using network identifiers
     */
    function getApeSwapV2TestCases() internal pure returns (SwapTestCase[] memory) {
        // Token addresses on BSC
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address BANANA = 0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95;
    
        // Pool addresses
        address WBNB_BANANA_POOL = 0xF65C1C0478eFDe3c19b49EcBE7ACc57BB6B1D713;
    
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // ApeSwap uses 0.2% fee (998/1000)
        bytes memory apeSwapFee = abi.encode(998, 1000);
        
        // Test 1: WBNB to BANANA
        // Using latest block (0) to avoid archive node requirement
        cases[0] = SwapTestCase({
            networkId: "bsc", // Uses BSC network from foundry.toml
            forkBlock: 0, // 0 = latest block
            fromToken: WBNB,
            toToken: BANANA,
            pool: WBNB_BANANA_POOL,
            amount: 328595232056825,
            expectedOutput: 0, // Dynamic
            sellBase: false,
            expectRevert: false,
            description: "WBNB to BANANA on BSC",
            moreInfo: apeSwapFee,
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    function getRDexV2TestCases() internal pure returns (SwapTestCase[] memory) {
        // Token addresses on BSC
        address RAC = 0x024a9AD0ECFaa8b3566D3310AFFb358379a55e7a;
        address BUSD = 0x55d398326f99059fF775485246999027B3197955;
    
        // Pool addresses
        address RAC_BUSD_POOL = 0x9f3E1B10c58384Ab472393455d2f870427fF9153;
    
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // RDX uses 0.3% fee (997/1000)
        bytes memory rdxFee = abi.encode(997, 1000);
        
        // Test 1: RAC to BUSD
        // Using latest block (0) to avoid archive node requirement
        // https://bscscan.com/tx/0x6877385a5544fbe6b4d692ef57ab8ea0b824ac186ce34d0e6275d586dd183335
        // https://app.blocksec.com/explorer/tx/bsc/0x1a80c3d5edd7996701bb2e78b982c1e1c3dbd826dab347cf3b0b4ef53bca825a?event=simulation&type=0&timestamp=1754894565307
        cases[0] = SwapTestCase({
            networkId: "bsc", // Uses BSC network from foundry.toml
            forkBlock: 57189200 - 1, // 0 = latest block
            fromToken: RAC,
            toToken: BUSD,
            pool: RAC_BUSD_POOL,
            amount: 1000 * 10 ** 18,
            expectedOutput: 21.220422771913875190 * 10 ** 18,
            sellBase: true,
            expectRevert: false,
            description: "RAC to BUSD on BSC",
            moreInfo: rdxFee,
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getLynexTestCases() internal pure returns (SwapTestCase[] memory) {
        address LYNX = 0x1a51b19CE03dbE0Cb44C1528E34a7EDD7771E9Af;
        address USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;

        address LYNX_USDC_POOL = 0x3E78c1F766D7FE2c3dceF6aFe6609966540B6391;

        // Lynex uses 0.5% fee (995/1000)
        bytes memory lynexFee = abi.encode(995, 1000);
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // https://lineascan.build/tx/0xc1de66fb17508e61d5c9e4925bae20b53ec809d837d5409260f08e88f241faf3
        cases[0] = SwapTestCase({
            networkId: "linea",
            forkBlock: 21889650 - 1,
            fromToken: USDC,
            toToken: LYNX,
            pool: LYNX_USDC_POOL,
            amount: 1.748546 * 10 ** 6 + 1, // Add 1 wei cause adapter will leave 1 wei for reduce gas cost
            expectedOutput: 156.966805548135144944 * 10 ** 18,
            sellBase: true,
            expectRevert: false,
            description: "USDC to LYNX on Linea",
            moreInfo: lynexFee,
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    function getAVAXTestCase() internal pure returns (SwapTestCase[] memory) {
        address WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
        address FRAX = 0xD24C2Ad096400B6FBcd2ad8B24E7acBc21A1da64;

        address WAVAX_FRAX_POOL = 0x677aFf5D7AA11BA5AD43C020B0860ff04bC1f69F;

        SwapTestCase[] memory cases = new SwapTestCase[](1);
        cases[0] = SwapTestCase({
            networkId: "avax",
            forkBlock: 0, // 0 = latest block
            fromToken: FRAX,
            toToken: WAVAX,
            pool: WAVAX_FRAX_POOL,
            amount: 1000 * 10 ** 18,
            expectedOutput: 0,
            sellBase: false,
            expectRevert: false,
            description: "FRAX to WAVAX on AVAX", // Updated description
            moreInfo: abi.encode(9975, 1000), // Standard Uniswap V2 fee (0.3%)
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    function getMonadJoeTestCases() internal pure returns (SwapTestCase[] memory) {
        address JOE = 0x371c7ec6D8039ff7933a2AA28EB827Ffe1F52f07;
        address WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;

        address JOE_WMON_PAIR = 0xD38eD09999c1FB29cAB12862a51618ed52BA65A1;

        SwapTestCase[] memory cases = new SwapTestCase[](1);
        // https://monadvision.com/tx/0xd329b1e9591b7d576ebac0c43452aa49da487efdc653a8d143bef637417cce69
        cases[0] = SwapTestCase({
            networkId: "monad",
            forkBlock: 40847265 - 1,
            fromToken: WMON,
            toToken: JOE,
            pool: JOE_WMON_PAIR,
            amount: 49500000000000000000,
            expectedOutput: 18374430384319061977,
            sellBase: false,
            expectRevert: false,
            description: "WMON to JOE on Monad",
            moreInfo: abi.encode(997, 1000),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
} 