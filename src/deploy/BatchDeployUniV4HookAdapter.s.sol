// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@dex/adapter/UniV4HookAdapter.sol";

contract BatchDeployUniV4HookAdapter is Script {
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));
    
    struct ChainConfig {
        string name;
        uint256 chainId;
        string rpcUrl;
        address poolManager;
        address weth;
    }
    
    function run() public {
        console2.log("Deployer:", deployer);
        require(
            deployer == 0x399EfA78cAcD7784751CD9FBf2523eDf9EFDf6Ad,
            "Wrong deployer! Change the private key"
        );
        
        // Define all chains
        ChainConfig[] memory chains = new ChainConfig[](10);
        
        chains[0] = ChainConfig({
            name: "Ethereum",
            chainId: 1,
            rpcUrl: vm.envString("ETH_RPC_URL"),
            poolManager: 0x000000000004444c5dc75cB358380D2e3dE08A90,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        });
        
        chains[1] = ChainConfig({
            name: "Optimism",
            chainId: 10,
            rpcUrl: vm.envString("OP_RPC_URL"),
            poolManager: 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3,
            weth: 0x4200000000000000000000000000000000000006
        });
        
        chains[2] = ChainConfig({
            name: "Base",
            chainId: 8453,
            rpcUrl: vm.envString("BASE_RPC_URL"),
            poolManager: 0x498581fF718922c3f8e6A244956aF099B2652b2b,
            weth: 0x4200000000000000000000000000000000000006
        });
        
        chains[3] = ChainConfig({
            name: "Arbitrum",
            chainId: 42161,
            rpcUrl: vm.envString("ARB_RPC_URL"),
            poolManager: 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32,
            weth: 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
        });
        
        chains[4] = ChainConfig({
            name: "Polygon",
            chainId: 137,
            rpcUrl: vm.envString("POLYGON_RPC_URL"),
            poolManager: 0x67366782805870060151383F4BbFF9daB53e5cD6,
            weth: 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270
        });
        
        chains[5] = ChainConfig({
            name: "Avalanche",
            chainId: 43114,
            rpcUrl: vm.envString("AVAX_RPC_URL"),
            poolManager: 0x06380C0e0912312B5150364B9DC4542BA0DbBc85,
            weth: 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7
        });
        
        chains[6] = ChainConfig({
            name: "Blast",
            chainId: 81457,
            rpcUrl: vm.envString("BLAST_RPC_URL"),
            poolManager: 0x1631559198A9e474033433b2958daBC135ab6446,
            weth: 0x4300000000000000000000000000000000000004
        });
        
        chains[7] = ChainConfig({
            name: "BSC",
            chainId: 56,
            rpcUrl: vm.envString("BSC_RPC_URL"),
            poolManager: 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF,
            weth: 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
        });
        
        chains[8] = ChainConfig({
            name: "UniChain",
            chainId: 130,
            rpcUrl: vm.envString("UNICHAIN_RPC_URL"),
            poolManager: 0x1F98400000000000000000000000000000000004,
            weth: 0x4200000000000000000000000000000000000006
        });
        
        chains[9] = ChainConfig({
            name: "Monad",
            chainId: 143,
            rpcUrl: vm.envString("MONAD_RPC_URL"),
            poolManager: 0x188d586Ddcf52439676Ca21A244753fA19F9Ea8e,
            weth: 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A
        });
        
        // Deploy to all chains
        for (uint256 i = 0; i < chains.length; i++) {
            deployToChain(chains[i]);
        }
        
        console2.log("\n========================================");
        console2.log("All deployments complete!");
        console2.log("========================================");
    }
    
    function deployToChain(ChainConfig memory config) internal {
        console2.log("\n========================================");
        console2.log("Deploying on", config.name);
        console2.log("Chain ID:", config.chainId);
        console2.log("========================================");
        
        try vm.createSelectFork(config.rpcUrl) {
            console2.log("Connected to", config.name);
            console2.log("Current chain ID:", block.chainid);
            
            require(block.chainid == config.chainId, "Chain ID mismatch");
            
            vm.startBroadcast(deployer);
            
            UniV4HookAdapter adapter = new UniV4HookAdapter(
                config.poolManager,
                config.weth
            );
            
            vm.stopBroadcast();
            
            console2.log("SUCCESS!");
            console2.log("UniV4HookAdapter deployed at:", address(adapter));
            console2.log("PoolManager:", config.poolManager);
            console2.log("WETH:", config.weth);
            
            // Log for verification script
            console2.log("\nVerification command:");
            console2.log("forge verify-contract", address(adapter), "contracts/8/adapter/UniV4HookAdapter.sol:UniV4HookAdapter");
            console2.log("  --chain-id", config.chainId);
            console2.log("  --verifier-url https://api.etherscan.io/v2/api?chainid=", vm.toString(config.chainId));
            console2.log("  --etherscan-api-key $ETHERSCAN_API_KEY");
            console2.log("  --constructor-args $(cast abi-encode \"constructor(address,address)\"", config.poolManager, config.weth, ")");
            
        } catch Error(string memory reason) {
            console2.log("FAILED on", config.name);
            console2.log("Reason:", reason);
        } catch {
            console2.log("FAILED on", config.name, "- Unknown error");
        }
    }
}

