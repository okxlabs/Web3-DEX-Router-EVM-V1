// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";
import {SpecialToken} from "./SpecialToken.t.sol";
import {console2} from "forge-std/console2.sol"; // solhint-disable no-console

/**
 * @title AbstractAdapterTest
 * @dev Simple base contract for adapter testing
 * @dev Uses network identifiers from foundry.toml rpc_endpoints
 */
abstract contract AbstractAdapterTest is Test {
    uint256 internal constant ORIGIN_PAYER =
        0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;

    // Simplified swap test case struct using network identifiers
    struct SwapTestCase {
        // Test case information
        string description;
        // Network information
        string networkId; // Network identifier from foundry.toml (e.g., "bsc", "eth", "arb")
        uint256 forkBlock;
        // Transaction information
        address fromToken;
        address toToken;
        address pool;
        uint256 amount;
        uint256 expectedOutput; // expected output (0 for dynamic)
        bool sellBase;
        bool expectRevert; // true if this test case is expected to revert
        bytes moreInfo; // adapter-specific data
        address fromTokenPreTo; // address to transfer tokens to (address(0) for default behavior to customAdapter itself)
    }

    // Network state tracking
    struct NetworkState {
        string currentNetworkId;
        uint256 currentForkBlock;
        uint256 forkId;
        bool isActive;
    }

    SwapTestCase[] internal testCases;
    NetworkState internal currentNetwork;
    address public customAdapter;
    SpecialToken internal specialToken; // Use SpecialToken instead of standard deal
    address public defaultPayer;

    // Events for logging
    event NetworkSwitch(string from, string to, uint256 blockNumber);
    event TestCaseStart(uint256 index, string description);
    event TestCaseComplete(uint256 index, bool success);

    /**
     * @dev Abstract functions that must be implemented
     */
    function createCustomAdapter(
        string memory networkId
    ) internal virtual returns (address);

    function getSwapTestCases()
        internal
        virtual
        returns (SwapTestCase[][] memory);

    /**
     * @dev Simple setup function
     */
    function setUp() public virtual {
        // Load test cases
        SwapTestCase[][] memory cases = getSwapTestCases();
        require(cases.length > 0, "No test cases provided");

        for (uint256 i = 0; i < cases.length; i++) {
            for (uint256 j = 0; j < cases[i].length; j++) {
                testCases.push(cases[i][j]);
            }
        }
    }

    /**
     * @dev Run all test cases
     */
    function test_AllCases() public {
        for (uint256 i = 0; i < testCases.length; i++) {
            _runTestCase(testCases[i], i);
        }
    }

    /**
     * @dev Run a single test case
     */
    function _runTestCase(
        SwapTestCase memory testCase,
        uint256 index
    ) internal {
        emit TestCaseStart(index, testCase.description);
        console2.log("=== Test Case %s: %s ===", index, testCase.description);

        bool success = false;

        try this._executeTestCase(testCase) {
            success = true;
            console2.log("[PASS] Test case %s completed successfully", index);
        } catch Error(string memory reason) {
            console2.log("[FAIL] Test case %s failed: %s", index, reason);
        } catch (bytes memory) {
            console2.log("[FAIL] Test case %s failed with low-level error", index);
        }

        emit TestCaseComplete(index, success);
        require(
            success,
            string(
                abi.encodePacked("Test case ", vm.toString(index), " failed")
            )
        );
    }

    /**
     * @dev Execute test case (external for try-catch)
     */
    function _executeTestCase(SwapTestCase memory testCase) external {
        // Switch to test case network using network identifier
        _switchToNetwork(testCase.networkId, testCase.forkBlock);
        
        // Execute swap
        _performSwap(testCase);
    }

    /**
     * @dev Core swap execution logic
     */
    function _performSwap(SwapTestCase memory testCase) internal {
        // Initialize SpecialToken
        specialToken = new SpecialToken();
        // Create adapter
        customAdapter = createCustomAdapter(testCase.networkId);
        // Set default payer
        defaultPayer = address(customAdapter); /// @notice Payer is set by dexrouter.

        // Setup tokens
        if (
            specialToken.wealthyHolders(testCase.networkId, testCase.fromToken) !=
            address(0)
        ) {
            // Special token transfer whale
            specialToken.specialDeal(
                testCase.networkId,
                testCase.fromToken,
                address(customAdapter),
                testCase.amount
            );
        } else {
            deal(testCase.fromToken, address(customAdapter), testCase.amount);
        }

        // Record initial balances
        uint256 initialFromBalance = IERC20(testCase.fromToken).balanceOf(
            address(customAdapter)
        );
        uint256 initialToBalance = IERC20(testCase.toToken).balanceOf(
            address(this)
        ); // Output goes to test contract

        // Transfer tokens to fromTokenPreTo address if specified
        if (testCase.fromTokenPreTo != address(0)) {
            vm.startPrank(address(customAdapter));
            IERC20(testCase.fromToken).transfer(
                testCase.fromTokenPreTo,
                testCase.amount
            );
            vm.stopPrank();
        }

        // Execute swap
        bool success;
        bytes memory returnData;

        if (testCase.expectRevert) {
            vm.expectRevert();
        }

        vm.startPrank(address(this), address(this)); // @notice: like EOA user
        if (testCase.sellBase) {
            (success, returnData) = customAdapter.call(
                abi.encodePacked(
                    abi.encodeWithSignature(
                        "sellBase(address,address,bytes)",
                        address(this),
                        testCase.pool,
                        testCase.moreInfo
                    ),
                ORIGIN_PAYER + uint(uint160(defaultPayer)) //payer origin
                )
            );
        } else {
            (success, returnData) = customAdapter.call(
                abi.encodePacked(
                    abi.encodeWithSignature(
                        "sellQuote(address,address,bytes)",
                        address(this),
                        testCase.pool,
                        testCase.moreInfo
                    ),
                ORIGIN_PAYER + uint(uint160(defaultPayer)) //payer origin
                )
            );
        }
        vm.stopPrank();

        require(success, string(abi.encodePacked("Swap failed: ", returnData)));

        // Check results
        uint256 finalFromBalance = IERC20(testCase.fromToken).balanceOf(
            address(customAdapter)
        );
        uint256 finalToBalance = IERC20(testCase.toToken).balanceOf(
            address(this)
        ); // Output is in test contract

        uint256 outputReceived = finalToBalance - initialToBalance;

        if (testCase.expectRevert) {
            // For expected reverts, verify no state changes occurred
            if (testCase.fromTokenPreTo == address(0)) {
                // Standard case: tokens should remain in adapter
                require(
                    finalFromBalance == initialFromBalance,
                    "From token balance should be unchanged after revert"
                );
            } else {
                // Pre-transfer case: adapter should have initialFromBalance - amount
                require(
                    finalFromBalance == initialFromBalance - testCase.amount,
                    "Adapter should have initialFromBalance - amount after pre-transfer and revert"
                );
            }
            require(
                outputReceived == 0,
                "No output tokens should be received after revert"
            );
        } else {
            // For successful swaps, validate normal success conditions
            // Check expected output if specified
            if (testCase.expectedOutput > 0) {
                require(
                    outputReceived == testCase.expectedOutput || // Normal case
                    outputReceived - 1 == testCase.expectedOutput, // Adapter may leave for 1 wei for reduce gas cost
                    string(abi.encodePacked(
                        "Output amount mismatch: ",
                        "received: ",
                        vm.toString(outputReceived), " != ",
                        "expected: ",
                        vm.toString(testCase.expectedOutput)))
                );
            }
            // Check from token balance
            if (testCase.fromTokenPreTo == address(0)) {
                // Standard case: adapter should have spent the tokens
                require(
                    finalFromBalance == initialFromBalance - testCase.amount || // Normal case
                finalFromBalance - 1 == initialFromBalance - testCase.amount, // Adapter may leave for 1 wei for reduce gas cost
                    string(abi.encodePacked(
                        "From token balance mismatch: ",
                        "received: ",
                        vm.toString(finalFromBalance), " != ",
                        "expected: ",
                        vm.toString(initialFromBalance - testCase.amount)
                    ))
                );
            }
        }
    }

    /**
     * @dev Switch to a specific network using network identifier
     * @param networkId Network identifier from foundry.toml (e.g., "bsc", "eth", "arb")
     * @param forkBlock Block number to fork at
     */
    function _switchToNetwork(
        string memory networkId,
        uint256 forkBlock
    ) internal {
        // Skip if already on correct network
        if (
            currentNetwork.isActive &&
            keccak256(bytes(currentNetwork.currentNetworkId)) ==
            keccak256(bytes(networkId)) &&
            currentNetwork.currentForkBlock == forkBlock
        ) {
            return;
        }

        // Log network switch
        if (currentNetwork.isActive) {
            emit NetworkSwitch(
                currentNetwork.currentNetworkId,
                networkId,
                forkBlock
            );
        }

        // Create new fork using network identifier
        // This will automatically use the RPC URL from foundry.toml [rpc_endpoints]
        uint256 forkId;
        if (forkBlock == 0) {
            forkId = vm.createSelectFork(networkId);
        } else {
            forkId = vm.createSelectFork(networkId, forkBlock);
        }

        // Update network state
        currentNetwork = NetworkState({
            currentNetworkId: networkId,
            currentForkBlock: forkBlock,
            forkId: forkId,
            isActive: true
        });

        // console2.log("Switched to network: %s at block %s", networkId, forkBlock);
    }

    /**
     * @dev Get current network information
     */
    function getCurrentNetwork() external view returns (NetworkState memory) {
        return currentNetwork;
    }

    /**
     * @dev Helper function to add test cases dynamically
     */
    function addTestCase(SwapTestCase memory testCase) internal {
        testCases.push(testCase);
    }

    receive() external payable {
    }

    fallback() external payable {
    }
}
