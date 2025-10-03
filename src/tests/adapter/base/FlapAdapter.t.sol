// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AbstractAdapterTest} from "../common/AbstractAdapterTest.t.sol";
import {FlapAdapter} from "@dex/adapter/FlapAdapter.sol";
import {ExactInputParams} from "@dex/interfaces/IPortal.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";
import "forge-std/console2.sol";

contract FlapAdapterTest is AbstractAdapterTest {

    // Network-specific configurations
    mapping(string => address) internal flapPortals;
    mapping(string => address) internal wrappedTokens;

    // XLayer tokens
    address internal XStock = 0x53C66Ee89D09De290C2F259c5BEA41cD761d1111;
    address internal OKBeaver = 0xf671b45c88c307971d178C1E87DA994C62Ff1111;
    address internal WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;

    // BNB tokens
    address internal WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal FLAP_TOKEN_BNB = 0x38d2061F888a7896367aF8A8361D07817D4E684A;

    function createCustomAdapter(
        string memory networkId
    ) internal override returns (address) {
        // Flap Portal addresses per network
        flapPortals["xlayer"] = 0xb30D8c4216E1f21F27444D2FfAee3ad577808678;
        flapPortals["bsc"] = 0xe2cE6ab80874Fa9Fa2aAE65D277Dd6B8e65C9De0;
        
        // Wrapped token addresses per network
        wrappedTokens["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b; // WOKB
        wrappedTokens["bsc"] = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB

        address flapPortal = flapPortals[networkId];
        address wrappedToken = wrappedTokens[networkId];
        require(flapPortal != address(0), "Unsupported network");
        require(wrappedToken != address(0), "Unsupported network");
        
        return address(new FlapAdapter(flapPortal, wrappedToken));
    }

    function getSwapTestCases()
        internal
        override
        view
        returns (SwapTestCase[][] memory)
    {
        SwapTestCase[][] memory cases = new SwapTestCase[][](2);
        cases[0] = getXLayerTestCases();
        cases[1] = getBNBTestCases();

        return cases;
    }

    function getXLayerTestCases()
        internal
        view
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // Fix: Match the ExactInputParams with the actual swap direction
        ExactInputParams memory params1 = ExactInputParams({
            inputToken: WOKB,  // Input token should match fromToken
            outputToken: XStock, // Output token should match toToken
            inputAmount: 0.000075 * 10 ** 18,
            minOutputAmount: 0, // Set to 0 for testing, real value would be calculated
            permitData: ""
        });

        // WOKB -> XStock
        // https://www.oklink.com/x-layer/tx/0x764602ef0df6c51d92701bc96fdf5c3d982a85c74c6302f1b4509d1f967ff9ee
        cases[0] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 32207580 - 1,
            fromToken: WOKB,
            toToken: XStock,
            pool: address(0),
            amount: 0.05 * 10 ** 18, // 0.000075 WOKB
            expectedOutput: 1035074653168234088428680, // dynamic
            sellBase: false,
            expectRevert: false,
            description: "WOKB to XStock on XLayer FlapAdapter",
            moreInfo: abi.encode(params1),
            fromTokenPreTo: address(0)
        });

        // XStock to WOKB
        // https://www.oklink.com/x-layer/tx/0x243dbbb61294e0fd512b8ba5c12cc7dd807b5cf63f7911ffd92a9ec87c68be5d
        ExactInputParams memory params2 = ExactInputParams({
            inputToken: XStock,
            outputToken: WOKB,
            inputAmount: 8344444137404781294501649,
            minOutputAmount: 0, // Set to 0 for testing, real value would be calculated
            permitData: ""
        });

        cases[1] = SwapTestCase({
            networkId: "xlayer",
            forkBlock: 32221262 - 1,
            fromToken: XStock,
            toToken: WOKB,
            pool: address(0),
            amount: 8344444137404781294501649,
            expectedOutput: 386854397091528676,
            sellBase: true,
            expectRevert: false,
            description: "XStock to WOKB on XLayer FlapAdapter",
            moreInfo: abi.encode(params2),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function getBNBTestCases()
        internal
        view
        returns (SwapTestCase[] memory)
    {
        SwapTestCase[] memory cases = new SwapTestCase[](2);

        // WBNB to Flap Token (Binance Dog)
        ExactInputParams memory params1 = ExactInputParams({
            inputToken: WBNB,
            outputToken: FLAP_TOKEN_BNB,
            inputAmount: 1000 * 10 ** 18, // 0.01 BNB
            minOutputAmount: 0,
            permitData: ""
        });

        cases[0] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 62151558, // More recent BSC block
            fromToken: WBNB,
            toToken: FLAP_TOKEN_BNB,
            pool: address(0),
            amount: 1 * 10 ** 18,
            expectedOutput: 0, // dynamic
            sellBase: true,
            expectRevert: false,
            description: "WBNB to Flap Token (Binance Dog) on BSC",
            moreInfo: abi.encode(params1),
            fromTokenPreTo: address(0)
        });

        // Flap Token (Binance Dog) to WBNB
        ExactInputParams memory params2 = ExactInputParams({
            inputToken: FLAP_TOKEN_BNB,
            outputToken: WBNB,
            inputAmount: 1000 * 10 ** 18, // 1000 Flap tokens
            minOutputAmount: 0,
            permitData: ""
        });

        cases[1] = SwapTestCase({
            networkId: "bsc",
            forkBlock: 62151558, // More recent BSC block
            fromToken: FLAP_TOKEN_BNB,
            toToken: WBNB,
            pool: address(0),
            amount: 1000 * 10 ** 18,
            expectedOutput: 0, // dynamic
            sellBase: true,
            expectRevert: false,
            description: "Flap Token (Binance Dog) to WBNB on BSC",
            moreInfo: abi.encode(params2),
            fromTokenPreTo: address(0)
        });

        return cases;
    }

    function testRefund() public {
        // Initialize network configs for XLayer
        flapPortals["xlayer"] = 0xb30D8c4216E1f21F27444D2FfAee3ad577808678;
        wrappedTokens["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        
        FlapAdapter flapAdapter = new FlapAdapter(
            flapPortals["xlayer"], 
            wrappedTokens["xlayer"]
        );

        // Use a large amount that will hit the graduation threshold
        // This should trigger the refund mechanism when graduation occurs
        ExactInputParams memory params = ExactInputParams({
            inputToken: WOKB,
            outputToken: OKBeaver,
            inputAmount: 500 * 10 ** 18, // Large amount to hit graduation and trigger refund
            minOutputAmount: 0, // Set to 0 for testing, real value would be calculated
            permitData: ""
        });

        _switchToNetwork("xlayer", 33013177); // Use old block so graduation doesn't occur
        
        // Provide initial WOKB balance to the adapter for the test
        deal(WOKB, address(flapAdapter), params.inputAmount);
        
        uint256 payerOrigin = ORIGIN_PAYER + uint(uint160(address(this)));
        uint256 testContractNativeBalanceBefore = address(this).balance;
    
        
        // Use the same pattern as AbstractAdapterTest with abi.encodePacked
        (bool success, ) = address(flapAdapter).call(
            abi.encodePacked(
                abi.encodeWithSignature(
                    "sellBase(address,address,bytes)",
                    address(this),
                    address(0),
                    abi.encode(params)
                ),
                payerOrigin //payer origin
            )
        );
        
        require(success, "Graduation transaction should succeed");
        console2.log("Graduation transaction completed successfully");
        
        uint256 nativeRefundReceived = address(this).balance - testContractNativeBalanceBefore;
        
        // Verify the adapter has no remaining balances
        assertEq(address(flapAdapter).balance, 0, "Adapter should have 0 native balance after refund");
        require(nativeRefundReceived == 419438421069508988842, "Should have refunded native OKB");
    }

    function testDeployedAdapter() public {
        // Fork from a specific X Layer block to access the deployed contract
        // Using block 33766562 which is the block where the contract was deployed
        vm.createSelectFork("xlayer");
        
        address flapAdapter = 0xa43F2E6e8313B46dDcb9190CE856AF0089320956;
        FlapAdapter flapAdapterContract = FlapAdapter(payable(flapAdapter));
        
        // Initialize network configs for verification
        flapPortals["xlayer"] = 0xb30D8c4216E1f21F27444D2FfAee3ad577808678;
        wrappedTokens["xlayer"] = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;
        
        assertEq(flapAdapterContract.FLAP_PORTAL(), flapPortals["xlayer"]);
        assertEq(flapAdapterContract.WNATIVE(), wrappedTokens["xlayer"]);

        // Give this test contract some WOKB tokens to work with
        uint256 initialTestBalance = 1000 * 10 ** 18;
        deal(WOKB, address(this), initialTestBalance);
        
        ExactInputParams memory params = ExactInputParams({
            inputToken: WOKB,
            outputToken: OKBeaver,
            inputAmount: 0.5 * 10 ** 18,
            minOutputAmount: 0,
            permitData: ""
        });

        // Record initial balances
        uint256 testContractInitialBalance = IERC20(WOKB).balanceOf(address(this));
        uint256 adapterInitialBalance = IERC20(WOKB).balanceOf(address(flapAdapterContract));

        // Transfer tokens to the adapter for the swap
        IERC20(WOKB).transfer(address(flapAdapterContract), params.inputAmount);
        
        // Record balances after transfer
        uint256 testContractAfterTransfer = IERC20(WOKB).balanceOf(address(this));
        uint256 adapterAfterTransfer = IERC20(WOKB).balanceOf(address(flapAdapterContract));
        
        // Verify transfer worked correctly
        assertEq(testContractAfterTransfer, testContractInitialBalance - params.inputAmount, "Test contract should have sent WOKB");
        assertEq(adapterAfterTransfer, adapterInitialBalance + params.inputAmount, "Adapter should have received WOKB");
        
        // Execute the swap
        flapAdapterContract.sellBase(address(this), address(0), abi.encode(params));
        
        // Record final balances
        uint256 testContractFinalBalance = IERC20(WOKB).balanceOf(address(this));
        uint256 adapterFinalBalance = IERC20(WOKB).balanceOf(address(flapAdapterContract));
        uint256 outputTokenBalance = IERC20(OKBeaver).balanceOf(address(this));
        
        // Verify the adapter consumed the WOKB tokens for the swap
        assertEq(adapterFinalBalance, 0, "Adapter should have consumed all WOKB tokens for the swap");
        
        // The test contract balance should remain the same (it already sent the tokens)
        assertEq(testContractFinalBalance, testContractAfterTransfer, "Test contract balance should remain unchanged after swap");
        
        // Verify we received some output tokens from the swap
        assertGt(outputTokenBalance, 0, "Should have received some OKBeaver tokens from the swap");
    }
}