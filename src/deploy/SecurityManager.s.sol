// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "@dex/SecurityManager.sol";

/// @notice Management-plane surface of the already-deployed CREATE2 deploy factory.
interface IDeployFactory {
    function deploy(bytes memory initCode, bytes32 salt) external returns (address payable);
    function getAddress(bytes memory initCode, bytes32 salt) external view returns (address);
}

/// @title Deploy SecurityManager through the deterministic CREATE2 factory.
/// @dev Simulate (default):  forge script src/deploy/SecurityManager.s.sol --rpc-url ethw
///      Broadcast:           forge script src/deploy/SecurityManager.s.sol --rpc-url ethw --broadcast
///      Per-chain config lives in the constants below; the address still varies per chain because
///      the constructor args (proxy / whitelist) are baked into the initCode.
contract DeploySecurityManager is Script {
    // --- Per-chain config: fill before running ---
    address constant TOKEN_APPROVE_PROXY = 0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58;
    address constant ADMIN = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;

    // Per-chain too. Solidity forbids `address[] constant`, so it is built in a function;
    // keep it edited alongside the two constants above.
    function initialWhitelist() internal pure returns (address[] memory list) {
        list = new address[](2);
        list[0] = 0x5E1f62Dac767b0491e3CE72469C217365D5B48cC;
        list[1] = 0x25ED72C3f671b626810A6dB597DCFD50F215A423;
    }

    // --- Chain-invariant config ---
    address constant DEPLOY_FACTORY = 0xFaC897544659Fb136C064d5428947f5BC9cC1Fa2;
    bytes32 constant SALT = keccak256("SecurityManager.v1");

    // Read from .env (forge auto-loads it); never hardcoded in source.
    address deployer = vm.rememberKey(vm.envUint("PRIVATE_KEY"));

    function run() public {
        console2.log("Deployer:", deployer);
        console2.log("Chain ID:", block.chainid);

        require(DEPLOY_FACTORY.code.length > 0, "DeployFactory not on this chain");

        // initCode = creationCode ++ abi.encode(constructor args).
        bytes memory initCode = abi.encodePacked(
            type(SecurityManager).creationCode,
            abi.encode(TOKEN_APPROVE_PROXY, ADMIN, initialWhitelist())
        );

        IDeployFactory factory = IDeployFactory(DEPLOY_FACTORY);
        address predicted = factory.getAddress(initCode, SALT);
        console2.log("Predicted SecurityManager:", predicted);

        if (predicted.code.length > 0) {
            console2.log("Already deployed, skipping.");
        } else {
            vm.startBroadcast(deployer);
            address deployed = factory.deploy(initCode, SALT);
            vm.stopBroadcast();

            require(deployed == predicted, "deployed != predicted");
            require(deployed.code.length > 0, "no code after deploy");
            console2.log("SecurityManager deployed at:", deployed);
        }

        console2.log("Follow-up (via multisig):");
        console2.log("  1. transferOwnership ->", predicted);
        console2.log("  2. grantRole(SECURITY_ROLE, <security company>) on", predicted);
    }
}
