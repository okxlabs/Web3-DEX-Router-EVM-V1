const fs = require("fs");

let deployed;
const networkName = process.argv[2];
if (networkName) {
  // node 直接调用: node scripts/tools/ureplace.js <network>
  const base = require(`../deployed/${networkName}/base`);
  deployed = { base };
} else {
  // hardhat 环境: npx hardhat run scripts/tools/ureplace.js --network <network>
  deployed = require('../deployed');
}

const UNXSWAP_ROUTER_PATH = "./contracts/8/libraries/CommonUtils.sol";
const PMMROUTER_PATH = "./contracts/8/PMMRouter.sol";
const EIP712_PATH = "./contracts/8/libraries/draft-EIP712Upgradable.sol";
const UNIV3_PATH = "./contracts/8/UnxswapV3Router.sol";
const UNIV3_EXACTOUT_PATH = "./contracts/8/UnxswapV3ExactOutRouter.sol";

const EMPTY_FF_FACTORY = "0x0000000000000000000000000000000000000000000000000000000000000000" // 32bytes

// Replaces the contract address in the constant part of the UnxswapRouter file
// _WETH, _APPROVE_PROXY_32, _WNATIVE_RELAY_32 Three constant addresses
// npx hardhat run scripts/tools/ureplace.js [network name, eg: eth]
function replace_contant(UnxswapRouterPath) {
  // console.log(deployed.base);

  // Reading the file
  fs.readFile(UnxswapRouterPath, function (err, data) {
    if (err) {
      return console.error(err);
    }

    let context = data.toString();
    // address public constant
    context = context.replace(/_WETH\s+=\s+0x[0-9a-fA-F]+/, "_WETH = " + deployed.base.wNativeToken)
    context = context.replace(/_APPROVE_PROXY\s+=\s+0x[0-9a-fA-F]+/, "_APPROVE_PROXY = " + deployed.base.tokenApproveProxy)
    context = context.replace(/_WNATIVE_RELAY\s+=\s+0x[0-9a-fA-F]+/, "_WNATIVE_RELAY = " + deployed.base.wNativeRelayer)

    fs.writeFile(UnxswapRouterPath, context, (err) => {
      if (err) {
        console.log(err);
      }
    });

    console.log("replace finish !")
  });
}

function replace_pmm_contant(PMMROUTER_PATH) {
  // console.log(deployed.base);

  // Reading the file
  fs.readFile(PMMROUTER_PATH, function (err, data) {
    if (err) {
      return console.error(err);
    }

    let context = data.toString();
    // address public constant
    context = context.replace(/_FACTORY\s=\s\w*/, "_FACTORY = " + deployed.base._FACTORY)

    fs.writeFile(PMMROUTER_PATH, context, (err) => {
      if (err) {
        console.log(err);
      }
    });

    console.log("replace finish !")
  });
}

function replace_pmm_eip712_contant(EIP712_PATH) {
  // console.log(deployed.base);

  // Reading the file
  fs.readFile(EIP712_PATH, function (err, data) {
    if (err) {
      return console.error(err);
    }

    let context = data.toString();
    // address public constant
    context = context.replace(/_CACHED_DOMAIN_SEPARATOR\s=\s\w*/, "_CACHED_DOMAIN_SEPARATOR = " + deployed.base._CACHED_DOMAIN_SEPARATOR)
    context = context.replace(/_HASHED_NAME\s=\s\w*/, "_HASHED_NAME = " + deployed.base._HASHED_NAME)
    context = context.replace(/_HASHED_VERSION\s=\s\w*/, "_HASHED_VERSION = " + deployed.base._HASHED_VERSION)
    context = context.replace(/_TYPE_HASH\s=\s\w*/, "_TYPE_HASH = " + deployed.base._TYPE_HASH)
    context = context.replace(/_CACHED_CHAIN_ID\s=\s\w*/, "_CACHED_CHAIN_ID = " + deployed.base._CACHED_CHAIN_ID)
    context = context.replace(/_CACHED_THIS\s=\s\w*/, "_CACHED_THIS = " + deployed.base.dexRouter)

    fs.writeFile(EIP712_PATH, context, (err) => {
      if (err) {
        console.log(err);
      }
    });

    console.log("replace finish !")
  });
}

function replace_univ3_contant(UnxswapRouterPath) {
  // console.log(deployed.base);

  // 如果 _FF_FACTORY 不存在或为空，使用 0x00 地址
  let factoryAddress = deployed.base._FF_FACTORY;
  if (factoryAddress == null || factoryAddress == "") {
    console.log("warning: _FF_FACTORY is null or empty, using 0x00 address");
    factoryAddress = EMPTY_FF_FACTORY;
  }
  // Reading the file
  fs.readFile(UnxswapRouterPath, function (err, data) {
    if (err) {
      return console.error(err);
    }

    let context = data.toString();
    // address public constant
    context = context.replace(/_FF_FACTORY\s+=\s+0x[0-9a-fA-F]+/, "_FF_FACTORY = " + factoryAddress);
    // context = context.replace(/_FF_FACTORY\s=\s\w*/, "_FF_FACTORY = " + factoryAddress);
    // if (deployed.base._POOL_INIT_CODE_HASH != null || deployed.base._POOL_INIT_CODE_HASH != "") {
    //   context = context.replace(/_POOL_INIT_CODE_HASH\s=\s\w*/, "_POOL_INIT_CODE_HASH = " + deployed.base._POOL_INIT_CODE_HASH);
    // }
    fs.writeFile(UnxswapRouterPath, context, (err) => {
      if (err) {
        console.log(err);
      }
    });

    console.log("replace finish !")
  });
}

function replace_univ3_exactout_contant(UnxswapRouterPath) {
  // console.log(deployed.base);

  // 如果 _FF_FACTORY 不存在或为空，使用 0x00 地址
  let factoryAddress = deployed.base._FF_FACTORY;
  if (factoryAddress == null || factoryAddress == "") {
    console.log("warning: _FF_FACTORY is null or empty, using 0x00 address");
    factoryAddress = EMPTY_FF_FACTORY;
  }
  // Reading the file
  fs.readFile(UnxswapRouterPath, function (err, data) {
    if (err) {
      return console.error(err);
    }

    let context = data.toString();
    // address public constant
    context = context.replace(/_FF_FACTORY_ADDRESS\s+=\s+address\(0x[0-9a-fA-F]+\)/, "_FF_FACTORY_ADDRESS = address(" + factoryAddress.replace("0xff", "0x").slice(0, 42) + ")");
    // context = context.replace(/_FF_FACTORY\s=\s\w*/, "_FF_FACTORY = " + factoryAddress);
    // if (deployed.base._POOL_INIT_CODE_HASH != null || deployed.base._POOL_INIT_CODE_HASH != "") {
    //   context = context.replace(/_POOL_INIT_CODE_HASH\s=\s\w*/, "_POOL_INIT_CODE_HASH = " + deployed.base._POOL_INIT_CODE_HASH);
    // }
    fs.writeFile(UnxswapRouterPath, context, (err) => {
      if (err) {
        console.log(err);
      }
    });

    console.log("replace finish !")
  });
}

replace_contant(UNXSWAP_ROUTER_PATH);
// replace_pmm_contant(PMMROUTER_PATH);
// replace_pmm_eip712_contant(EIP712_PATH);
replace_univ3_contant(UNIV3_PATH);
// replace_univ3_exactout_contant(UNIV3_EXACTOUT_PATH);