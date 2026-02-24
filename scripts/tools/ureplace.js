const fs = require("fs");
const { network } = require('hardhat');
const deployed = require('../deployed');
const gasLimitConfig = require('../gas_limit/native_transfer_gas');

// File paths
const CONSTANTS_PATH = "./contracts/8/libraries/Constants.sol";
const UNIV3_PATH = "./contracts/8/router/UnxswapV3Router.sol";
const UNIV3_EXACTOUT_PATH = "./contracts/8/router/UnxswapV3ExactOutRouter.sol";

// Default addresses for empty values
const EMPTY_FF_FACTORY = "0x0000000000000000000000000000000000000000000000000000000000000000"; // 32bytes
const EMPTY_ADDRESS = "0x0000000000000000000000000000000000000000";

/**
 * Replaces the network-specific constants in Constants.sol
 * - NATIVE_TOKEN_TRANSFER_GAS_LIMIT
 * - _WETH
 * - _APPROVE_PROXY
 * - _PERMIT2
 */
function replace_constants(constantsPath) {
  const networkName = network.name;
  console.log(`Replacing constants for network: ${networkName}`);

  let context = fs.readFileSync(constantsPath, 'utf8');

  // Replace NATIVE_TOKEN_TRANSFER_GAS_LIMIT
  const gasLimit = gasLimitConfig.getGasLimit(networkName);
  context = context.replace(
    /NATIVE_TOKEN_TRANSFER_GAS_LIMIT\s*=\s*\d+/,
    `NATIVE_TOKEN_TRANSFER_GAS_LIMIT = ${gasLimit}`
  );
  console.log(`  - NATIVE_TOKEN_TRANSFER_GAS_LIMIT = ${gasLimit}`);

  // Replace _WETH
  if (deployed.base.wNativeToken) {
    context = context.replace(
      /address constant _WETH\s*=\s*0x[0-9a-fA-F]+/,
      `address constant _WETH = ${deployed.base.wNativeToken}`
    );
    console.log(`  - _WETH = ${deployed.base.wNativeToken}`);
  }

  // Replace _APPROVE_PROXY
  if (deployed.base.tokenApproveProxy) {
    context = context.replace(
      /address constant _APPROVE_PROXY\s*=\s*0x[0-9a-fA-F]+/,
      `address constant _APPROVE_PROXY = ${deployed.base.tokenApproveProxy}`
    );
    console.log(`  - _APPROVE_PROXY = ${deployed.base.tokenApproveProxy}`);
  }

  // Replace _PERMIT2 - use empty address if permit2 is not set or empty
  let permit2Address = deployed.base.permit2;
  if (!permit2Address || permit2Address === "") {
    permit2Address = EMPTY_ADDRESS;
    console.log(`  - _PERMIT2 = ${permit2Address} (not configured, using zero address)`);
  } else {
    console.log(`  - _PERMIT2 = ${permit2Address}`);
  }
  context = context.replace(
    /address constant _PERMIT2\s*=\s*0x[0-9a-fA-F]+/,
    `address constant _PERMIT2 = ${permit2Address}`
  );

  fs.writeFileSync(constantsPath, context);
  console.log("Constants.sol replace finish!");
}

/**
 * Replaces the _FF_FACTORY constant in UnxswapV3Router.sol
 */
function replace_univ3_constant(unxswapRouterPath) {
  // Use empty address if _FF_FACTORY is not set or empty
  let factoryAddress = deployed.base._FF_FACTORY;
  if (!factoryAddress || factoryAddress === "") {
    console.log("warning: _FF_FACTORY is not configured, using zero address");
    factoryAddress = EMPTY_FF_FACTORY;
  }

  let context = fs.readFileSync(unxswapRouterPath, 'utf8');
  context = context.replace(
    /_FF_FACTORY\s*=\s*0x[0-9a-fA-F]+/,
    `_FF_FACTORY = ${factoryAddress}`
  );

  fs.writeFileSync(unxswapRouterPath, context);
  console.log(`UnxswapV3Router.sol _FF_FACTORY replace finish! (${factoryAddress})`);
}

/**
 * Replaces the _FF_FACTORY_ADDRESS constant in UnxswapV3ExactOutRouter.sol
 */
function replace_univ3_exactout_constant(unxswapExactOutRouterPath) {
  // Use empty address if _FF_FACTORY is not set or empty
  let factoryAddress = deployed.base._FF_FACTORY;
  if (!factoryAddress || factoryAddress === "") {
    console.log("warning: _FF_FACTORY is not configured, using zero address for _FF_FACTORY_ADDRESS");
    factoryAddress = EMPTY_ADDRESS;
  } else {
    // Convert _FF_FACTORY (bytes32 format: 0xff + address + padding) to address format
    // Remove "0xff" prefix and take the next 40 characters (20 bytes address)
    factoryAddress = "0x" + factoryAddress.slice(4, 44);
  }

  let context = fs.readFileSync(unxswapExactOutRouterPath, 'utf8');
  context = context.replace(
    /_FF_FACTORY_ADDRESS\s*=\s*address\(0x[0-9a-fA-F]+\)/,
    `_FF_FACTORY_ADDRESS = address(${factoryAddress})`
  );

  fs.writeFileSync(unxswapExactOutRouterPath, context);
  console.log(`UnxswapV3ExactOutRouter.sol _FF_FACTORY_ADDRESS replace finish! (address(${factoryAddress}))`);
}

// Execute replacements
console.log(`\n========== Starting ureplace.js for network: ${network.name} ==========\n`);

// Replace Constants.sol (NATIVE_TOKEN_TRANSFER_GAS_LIMIT, _WETH, _APPROVE_PROXY, _PERMIT2)
replace_constants(CONSTANTS_PATH);

// Replace UnxswapV3Router.sol (_FF_FACTORY)
replace_univ3_constant(UNIV3_PATH);

// Replace UnxswapV3ExactOutRouter.sol (_FF_FACTORY_ADDRESS)
replace_univ3_exactout_constant(UNIV3_EXACTOUT_PATH);
