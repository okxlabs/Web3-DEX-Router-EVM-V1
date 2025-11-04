// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {UniversalUniswapV3Adapter} from "@dex/adapter/TemplateAdapter/UniversalUniswapV3Adapter.sol";
import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";

/// @title UniversalUniswapV3Adapter
/// @notice Adapter tests for UniversalUniswapV3Adapter
/// @dev Uses the new AbstractAdapterTest harness to minimise boilerplate.
contract UniversalUniswapV3AdapterTest is AbstractAdapterTest {
    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO =
        1461446703485210103287273052203988822378723970342;

    // Mapping of network IDs to their native wrapped tokens
    mapping(string => address) internal nativeWrappedTokens;
    
    /**
     * @dev Create UniversalUniswapV3 adapter for the specified network
     * @param networkId The network identifier (e.g. "bsc", "mantle")
     */
    function createCustomAdapter(string memory networkId) internal override returns (address) {
        // Native wrapped token addresses per network
        nativeWrappedTokens["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // BSC_WBNB
        nativeWrappedTokens["mantle"] = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8; // MANTLE_WMNT
        nativeWrappedTokens["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // XLAYER_WOKB
        nativeWrappedTokens["linea"] = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f; // LINEA_WETH
        nativeWrappedTokens["cro"] = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23; // CRO_WCRO
        nativeWrappedTokens["polygon"] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // POLYGON_WMATIC
        nativeWrappedTokens["avax"] = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // AVALANCHE_WAVAX
        nativeWrappedTokens["base"] = 0x4200000000000000000000000000000000000006; // BASE_WETH

        address nativeWrappedToken = nativeWrappedTokens[networkId];
        require(nativeWrappedToken != address(0), "Unsupported network");
        
        return address(
            new UniversalUniswapV3Adapter(
                payable(nativeWrappedToken),
                MIN_SQRT_RATIO,
                MAX_SQRT_RATIO
            )
        );
    }

    /**
     * @dev Define test cases for Thena V3 swaps
     */
    function getSwapTestCases()
        internal
        pure
        override
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](11);
        // cases[0] = getThenaV3TestCases();
        // cases[1] = getAgniFinanceTestCases();
        // cases[2] = getOkieV3XlayerTestCases();
        // cases[3] = getEtherexFinanceTestCases();
        // cases[4] = getVVSFinanceV3TestCases();
        // cases[5] = getWDEXTestCases();
        // cases[6] = getRadioCACATestCases();
        // cases[7] = getDyorV3TestCases();
        // cases[8] = getPharaohV3Cases();
        cases[9] = getAerodromeCLTestCases();
        cases[10] = getHydrexTestCases();

        return cases;
    }

    /**
     * @dev Test cases for Hydrex swaps on Base
     * Transaction link: https://basescan.org/tx/0x662a3a95c81ff8068cbdd6efa30cb19032beb46152583b5bbd296ca191d36056
     * TODO: Fill in the following information from on-chain transaction:
     * - FROM_TOKEN: Address of token being sold
     * - TO_TOKEN: Address of token being bought
     * - POOL: Address of liquidity pool
     * - forkBlock: Transaction block number - 1
     * - amount: Input amount (with decimals)
     * - expectedOutput: Output amount (with decimals), use 0 if dynamic
     * - sellBase: true if selling base token, false if selling quote token
     * - fee: Fee tier (uint24, e.g., 10000 for 1%, 3000 for 0.3%)
     */
    function getHydrexTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // TODO: Fill in token addresses from on-chain transaction
        address FROM_TOKEN = 0x0000000000000000000000000000000000000000;
        address TO_TOKEN = 0x0000000000000000000000000000000000000000;
        address POOL = 0x0000000000000000000000000000000000000000;
        
        // Transaction: https://basescan.org/tx/0x662a3a95c81ff8068cbdd6efa30cb19032beb46152583b5bbd296ca191d36056
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: 0, // TODO: Fill in transaction block number - 1
            fromToken: FROM_TOKEN,
            toToken: TO_TOKEN,
            pool: POOL,
            amount: 0, // TODO: Fill in input amount (with decimals)
            expectedOutput: 0, // TODO: Fill in output amount (with decimals), use 0 if dynamic/unverified
            sellBase: true, // TODO: true if selling base token, false if selling quote token
            expectRevert: false,
            description: "FROM_TOKEN to TO_TOKEN on Hydrex", // TODO: Update with actual token names
            moreInfo: abi.encode(uint160(0), abi.encode(FROM_TOKEN, TO_TOKEN, uint24(0))), // TODO: Fill in fee tier
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    /**
     * @dev Test cases for Aerodrome CL swaps on Base
     * Transaction link: https://basescan.org/tx/0x002b581c8088f31906a816109da7ec52050b5b6a438eb8e4805e366abf9a558c
     * Transaction: WETH to USDC swap on Aerodrome CL (Uniswap V4 compatible)
     */
    function getAerodromeCLTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // Token addresses on Base network
        address WorthlessToken = 0x20173a75d8Ae180D64704eE162E5f97a2CF7Da77; // WorthlessToken
        address USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; // Circle: USDC Token
        address POOL = 0xFeef402e5F3A808C1Ff70350c0A85e0443c31e3E; // Aerodrome CL Pool
        
        // Transaction: WETH to USDC swap
        // Input: 0.021873944236736628 WETH (21873944236736628)
        // Output: 85.434442 USDC (85434442, USDC has 6 decimals)
        // From Swap event: amount0 = -85798740671858298611 (token0 sold), amount1 = 85434442 (token1 received)
        // Since user sold WETH and received USDC, and from Swap event amount1 is positive (USDC received),
        // this means token1 = USDC, token0 = other token (WorthlessToken or similar)
        // The actual swap was WETH -> USDC, so sellBase depends on pool token order
        // From the event: user received USDC (amount1 positive), so USDC is token1
        // If WETH is token0, then sellBase = true; if WETH is token1, then sellBase = false
        // Based on the transfer amounts and typical pool ordering (WETH < USDC address), WETH is likely token0
        cases[0] = SwapTestCase({
            networkId: "base",
            forkBlock: 37668814,
            fromToken: WorthlessToken,
            toToken: USDC,
            pool: POOL,
            amount: 85798740671858298611, // 85798740671858298611 WorthlessToken
            expectedOutput: 84922610, // on chain tx is 85.434442 USDC (6 decimals), but if position is 0, the output is 85.429466 USDC
            sellBase: false, // WorthlessToken is likely token1 (quote token) based on address ordering
            expectRevert: false,
            description: "WorthlessToken to USDC on Aerodrome CL",
            moreInfo: abi.encode(uint160(0), abi.encode(WorthlessToken, USDC, uint24(1))), // Fee tier: 10000 (1%)
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    /**
     * @dev Test cases for Pharaoh V3 swaps on Avalanche
     * Transaction link: https://snowscan.xyz/tx/0x54c1a7fae32ce20ffd87ea4280b0b2e5c247a4db16b56bfdaae43e868c539476
     */
    function getPharaohV3Cases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        // Token addresses
        address WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7; // Wrapped AVAX
        address PHAR = 0x13A466998Ce03Db73aBc2d4DF3bBD845Ed1f28E7; // Pharaoh Token
        address POOL = 0x062D76834F188b9E88c46381D327A7613250240C; // WAVAX/PHAR Pool
        
        // Transaction: WAVAX to PHAR swap
        // Input: 5.349671932217026773 WAVAX (5349671932217026773)
        // Output: 2,682.469238708072917831 PHAR (2682469238708072917831)
        // From Swap event: amount0 = -2682469238708072917831 (token0=PHAR sold), amount1 = 5349671932217026773 (token1=WAVAX received)
        // Since user sold WAVAX (token1) and received PHAR (token0), sellBase = false
        cases[0] = SwapTestCase({
            networkId: "avax",
            forkBlock: 71343723 - 1,
            fromToken: WAVAX,
            toToken: PHAR,
            pool: POOL,
            amount: 5349671932217026773, // 5.349671932217026773 WAVAX
            expectedOutput: 2682469238708072917831, // 2,682.469238708072917831 PHAR
            sellBase: false, // Selling WAVAX (token1), not base token
            expectRevert: false,
            description: "WAVAX to PHAR on Pharaoh V3",
            moreInfo: abi.encode(uint160(0), abi.encode(WAVAX, PHAR, uint24(0))),
            fromTokenPreTo: address(0)
        });
        
        return cases;
    }

    function getDyorV3TestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);

        address FORM_TOKEN = 0x5158c92b0afD985ad963A7755BD648e430ca5099;
        address TO_TOKEN = 0x679A80e5D2a0fD5aD01D701446d9397a662d9Bcf;
        address POOL = 0xCeEB9C788e4FC03EB799e002dabf071e3393Ee35;

        // https://www.oklink.com/zh-hans/x-layer/tx/0x7ce0e6be164d1b9941a4319bfdf12c02ba09627c5419f1152d568465a880ee9e
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 36331618 - 1,
            fromToken: FORM_TOKEN,
            toToken: TO_TOKEN,
            pool: POOL,
            amount: 1 * 10 ** 18,
            expectedOutput: 998501997253744881,
            sellBase: true,
            expectRevert: false,
            description: "STB to T2 on Dyor V3",
            moreInfo: abi.encode(uint160(0), abi.encode(FORM_TOKEN, TO_TOKEN, uint24(0))),
            fromTokenPreTo: address(0)
        });
        return cases;
    }

    function getRadioCACATestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        address RACA = 0x12BB890508c125661E03b09EC06E404bc9289040;
        address WBNB_RACA_POOL = 0x3f0CB8346ce04D8923Dcb1bE9552b011723e46AB;

        // https://bscscan.com/tx/0x91735f905597d2246dc712f029c222dde23c278bd1194788d8c5eccfa67731c5
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 61274377 - 1,
            fromToken: RACA,
            toToken: WBNB,
            pool: WBNB_RACA_POOL,
            amount: 10168626.636766333521362944 * 10 ** 18,
            expectedOutput: 0.600987876171391804 * 10 ** 18,
            sellBase: false,
            expectRevert: false,
            description: "RACA to WBNB on Radio CAC",
            moreInfo: abi.encode(uint160(0), abi.encode(RACA, WBNB, uint24(0))),
            fromTokenPreTo: address(0)
        });
        return cases;
    }

    function getWDEXTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        
        address WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        address USDT0 = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        address WMATIC_USDT0_POOL = 0x702d3438B2c6DE6911a6A43A673cE5593c797F74;
        // https://polygonscan.com/tx/0xa18ece5b031818a756da7aea5aae6f21d614cafb646a9f484176f13270d99737
        cases[0] = SwapTestCase({
            networkId: "polygon",
            forkBlock: 76523329 - 1,
            fromToken: WMATIC,
            toToken: USDT0,
            pool: WMATIC_USDT0_POOL,
            amount: 3147499147711281767326,
            expectedOutput: 795340356,
            sellBase: true,
            expectRevert: false,
            description: "WMATIC to USDT0 on Polygon",
            moreInfo: abi.encode(uint160(0), abi.encode(WMATIC, USDT0, uint24(0))),
            fromTokenPreTo: address(0)
        });
        return cases;
    }

    function getVVSFinanceV3TestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        address WCRO = 0x5C7F8A570d578ED84E63fdFA7b1eE72dEae1AE23;
        address USDC = 0xc21223249CA28397B4B6541dfFaEcC539BfF0c59;
        address USDC_WCRO_POOL = 0x67255a0AB5aDD6D65045E6E855842Ca8b8A2B625;
        //https://cronoscan.com/tx/0x9bd51581acb3c08478e321ca4321ace3c4527500c9fac099701b8568ddcfe73d
        SwapTestCase[] memory cases = new SwapTestCase[](1);
        cases[0] = SwapTestCase({
            networkId: "cro",
            forkBlock: 32068322 - 1,
            fromToken: USDC,
            toToken: WCRO,
            pool: USDC_WCRO_POOL,
            amount: 400 * 10 ** 6,
            expectedOutput: 1735114089020313384588,
            sellBase: true,
            expectRevert: false,
            description: "USDC to WCRO on VVS Finance V3",
            moreInfo: abi.encode(uint160(0), abi.encode(USDC, WCRO, uint24(0))),
            fromTokenPreTo: address(0)
        });
    
        return cases;
    }

    function getThenaV3TestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses
        address WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // Wrapped BNB
        address ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8; // Ethereum

        // Thena V3 (Algebra Integral) pool containing WBNB / ETH
        address WBNB_ETH_POOL = 0x58F04AAda1051885a3C4e296aaB0A454Ea1233A3;
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Test 1: WBNB to ETH
        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 55363063, // latest head
            fromToken: WBNB,
            toToken: ETH,
            pool: WBNB_ETH_POOL,
            amount: 1 * 10 ** 18, // 1 WBNB (BSC WBNB has 18 decimals)
            expectedOutput: 207698750360467694, 
            sellBase: false,
            expectRevert: false,
            description: "WBNB to ETH on Thena V3",
            moreInfo: abi.encode(uint160(0), abi.encode(WBNB, ETH, uint24(0))),
            fromTokenPreTo: address(0)
        });

        // Test 2: ETH to WBNB
        cases[1] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 0, // latest
            fromToken: ETH,
            toToken: WBNB,
            pool: WBNB_ETH_POOL,
            amount: 0.1 * 10 ** 18, // 0.1 ETH
            expectedOutput: 0, // dynamic
            sellBase: true,
            expectRevert: false,
            description: "ETH to WBNB on Thena V3",
            moreInfo: abi.encode(uint160(0), abi.encode(ETH, WBNB, uint24(0))),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getAgniFinanceTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on Mantle network
        address WMNT = 0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8;
        address WETH = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111;
        address USDT = 0x201EBa5CC46D216Ce6DC03F6a759e8E766e956aE;

        // Pool addresses
        address WMNT_USDT = 0xD08C50F7E69e9aeb2867DefF4A8053d9A855e26A;
        address WETH_USDT = 0x628f7131CF43e88EBe3921Ae78C4bA0C31872bd4;

        SwapTestCase[] memory cases = new SwapTestCase[](4);

        // Test 1: WMNT to USDT
        // //https://explorer.mantle.xyz/tx/0x49e745b9582d202b744a140c3a7e6aa8cd4a2bb2a282609b413696ddd899eebe
        cases[0] = SwapTestCase({
            networkId: "mantle", // Uses Mantle network from foundry.toml
            forkBlock: 62825725, // Block before the transaction
            fromToken: WMNT,
            toToken: USDT,
            pool: WMNT_USDT,
            amount: 0.415 * 10 ** 18, // 0.415 WMNT
            expectedOutput: 0.504974 * 10 ** 6,
            sellBase: true,
            expectRevert: false,
            description: "WMNT to USDT on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(WMNT, USDT)),
            fromTokenPreTo: address(0)
        });

        // Test 2: USDT to WMNT
        cases[1] = SwapTestCase({
            networkId: "mantle",
            forkBlock: 62825725,
            fromToken: USDT,
            toToken: WMNT,
            pool: WMNT_USDT,
            amount: 1000000, // 1 USDT (6 decimals)
            expectedOutput: 0,
            sellBase: false, // USDT is quote token
            expectRevert: false,
            description: "USDT to WMNT on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(USDT, WMNT)),
            fromTokenPreTo: address(0)
        });

        // Test 3: WETH to USDT
        cases[2] = SwapTestCase({
            networkId: "mantle",
            forkBlock: 62825725,
            fromToken: WETH,
            toToken: USDT,
            pool: WETH_USDT,
            amount: 1 ether, // 1 WETH
            expectedOutput: 0,
            sellBase: true,
            expectRevert: false,
            description: "WETH to USDT on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(WETH, USDT)),
            fromTokenPreTo: address(0)
        });

        // Test 4: USDT to WETH
        cases[3] = SwapTestCase({
            networkId: "mantle",
            forkBlock: 62825725,
            fromToken: USDT,
            toToken: WETH,
            pool: WETH_USDT,
            amount: 3000 * 10 ** 6, // 3000 USDT
            expectedOutput: 0,
            sellBase: false,
            expectRevert: false,
            description: "USDT to WETH on Mantle",
            moreInfo: abi.encode(uint160(0), abi.encode(USDT, WETH)),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getOkieV3XlayerTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {

        address WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // WOKB
        address USDC = 0x74b7F16337b8972027F6196A17a631aC6dE26d22; // USDC
        address USDT = 0x1E4a5963aBFD975d8c9021ce480b42188849D41d; // USDT
        address USDC_WOKB = 0x01cA49E4a864C49FeDd08B464c042d02598C3538; // USDC_WOKB
        address USDT_USDC = 0x2b0Fea5Cbe72dcd362fbcA452FEdD57F55747ae3;

        SwapTestCase[] memory cases = new SwapTestCase[](2);


        // Test 1: WOKB to USDC
        // https://www.oklink.com/x-layer/tx/0x6410c2b72c26cab1a678c974bf08a45983e120743e1f27449b2fa76528e3258b
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 31552191 - 1,
            fromToken: WOKB,
            toToken: USDC,
            pool: USDC_WOKB,
            amount: 59248269621225,
            expectedOutput: 27394,
            sellBase: false,
            expectRevert: false,
            description: "EQUA to WOKB on USDC",
            moreInfo: abi.encode(uint160(0), abi.encode(WOKB, USDC)),
            fromTokenPreTo: address(0)
        });

        // Test 2: USDC to USDT
        // https://www.oklink.com/x-layer/tx/0x7488890d8df542199ee23acdb9ce473806d23573eb2bb0a5e806abc83b98c2fa/log
        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 31793708 -1,
            fromToken: USDC,
            toToken: USDT,
            pool: USDT_USDC,
            amount: 4172816,
            expectedOutput: 4167156,
            sellBase: false,
            expectRevert: false,
            description: "USDT to USDC on OKIE",
            moreInfo: abi.encode(uint160(0), abi.encode(USDC, USDT)),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getEtherexFinanceTestCases()
        internal
        pure
        returns (SwapTestCase[] memory)
    {
        // Token addresses on linea
        address WETH = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
        address USDT = 0xA219439258ca9da29E9Cc4cE5596924745e12B93;

        // Pool addresses
        address WETH_USDT = 0xd5E04ba35908D7bF5BD2eAd7e3e14d21df07DC01;

        SwapTestCase[] memory cases = new SwapTestCase[](1);

        // Test 1: WETH to USDT
        // https://lineascan.build/tx/0xac0add9f82fc5f131963c32667ee16b55cef76d35aacda86ad9a2aacbdca7408
        cases[0] = SwapTestCase({
            networkId: "linea",
            forkBlock: 21882671 - 1,
            fromToken: WETH,
            toToken: USDT,
            pool: WETH_USDT,
            amount: 1.5 * 10 ** 18, // 0.45 WETH
            expectedOutput: 6445.447958 * 10 ** 6,
            sellBase: false,
            expectRevert: false,
            description: "WETH to USDT in Etherex on Linea",
            moreInfo: abi.encode(uint160(0), abi.encode(WETH, USDT)),
            fromTokenPreTo: address(0)
        });

        return cases;
    }
}
