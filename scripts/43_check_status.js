const hre = require("hardhat");
const { ethers, network } = hre;
const deployed = require('./deployed');
const { buildZkProvider, getZkContract, isZkSyncNetwork } = require("./utils/zksync");

const getProvider = () =>
    isZkSyncNetwork(hre, network.name) ? buildZkProvider(hre, network.name) : ethers.provider;

const getContract = async (contractName, address, provider) =>
    isZkSyncNetwork(hre, network.name)
        ? getZkContract(hre, contractName, address, provider)
        : ethers.getContractAt(contractName, address);

async function main() {
    // console.log(deployed);
    const dexRouter = deployed.base.newImpl
    const provider = getProvider();
    // check wnative relayer
    const WNativeRelayer = await getContract(
        "WNativeRelayer",
        deployed.base.wNativeRelayer,
        provider
    )
    // keccak256(abi.encode(address(0xf332761c673b59B21fF6dfa8adA44d78c12dEF09),uint(152)))
    const packedData = ethers.utils.solidityPack(
        ['uint256', 'uint256'],
        [dexRouter, 152]
    );
    let slot = ethers.utils.keccak256(packedData);
    let res = await provider.getStorageAt(WNativeRelayer.address, slot)
    const decodedBool = ethers.utils.defaultAbiCoder.decode(
        ["bool"], // The type we expect ("bool")
        res // The raw storage slot data
    )[0]; // Take the first (and only) decoded value
    console.log("wnative relayer config", decodedBool)

    // check tokenapprove proxy
    const TokenApproveProxy = await getContract("TokenApproveProxy", deployed.base.tokenApproveProxy, provider)
    let res2 = await TokenApproveProxy.allowedApprove(dexRouter)
    console.log("token approve proxy", res2)
    // check owner
    // const DexRouter = await ethers.getContractAt("contracts/8/DexRouter.sol:DexRouter", dexRouter)
    // let owner = await DexRouter.owner()
    // console.log("dexrouter owner", owner)
    // check initialized
    // let res___ = await ethers.provider.getStorageAt(deployed.base.newImpl, 0)
    // console.log(res___)
    // const decodedInitialized____ = ethers.utils.defaultAbiCoder.decode(
    //     ["uint"], // 
    //     // res___ // The raw storage slot data
    // )[0]; // Take the first (and only) decoded value
    // console.log("initialized", decodedInitialized____.toString() === ethers.BigNumber.from(1).toString());
    // check xbridge



}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });



// ╭---------------+--------------------------+------+--------+-------+-----------------------------------------------------╮
// | Name          | Type                     | Slot | Offset | Bytes | Contract                                            |
// +========================================================================================================================+
// | _initialized  | uint8                    | 0    | 0      | 1     | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | _initializing | bool                     | 0    | 1      | 1     | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | __gap         | uint256[50]              | 1    | 0      | 1600  | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | _owner        | address                  | 51   | 0      | 20    | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | __gap         | uint256[49]              | 52   | 0      | 1568  | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | _status       | uint256                  | 101  | 0      | 32    | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | __gap         | uint256[49]              | 102  | 0      | 1568  | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | wnative       | address                  | 151  | 0      | 20    | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// |---------------+--------------------------+------+--------+-------+-----------------------------------------------------|
// | okCallers     | mapping(address => bool) | 152  | 0      | 32    | contracts/8/utils/WNativeRelayer.sol:WNativeRelayer |
// ╰---------------+--------------------------+------+--------+-------+-----------------------------------------------------╯



// ╭----------------------------------+--------------------------+------+--------+-------+---------------------------╮
// | Name                             | Type                     | Slot | Offset | Bytes | Contract                  |
// +=================================================================================================================+
// | _initialized                     | uint8                    | 0    | 0      | 1     | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | _initializing                    | bool                     | 0    | 1      | 1     | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | __gap                            | uint256[50]              | 1    | 0      | 1600  | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | _owner                           | address                  | 51   | 0      | 20    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | __gap                            | uint256[49]              | 52   | 0      | 1568  | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | _paused                          | bool                     | 101  | 0      | 1     | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | __gap                            | uint256[49]              | 102  | 0      | 1568  | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | _status                          | uint256                  | 151  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | __gap                            | uint256[49]              | 152  | 0      | 1568  | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | allowedMpc                       | mapping(address => bool) | 201  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | whitelistedAddresses             | mapping(address => bool) | 202  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | _whitelistedSelectors_deprecated | mapping(bytes4 => bool)  | 203  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | whitelistedAdaptorIds            | mapping(uint256 => bool) | 204  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | whitelistedBridgeTo              | mapping(bytes32 => bool) | 205  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | whitelistedBridgeToken           | mapping(address => bool) | 206  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | whitelistedChainId               | mapping(uint256 => bool) | 207  | 0      | 32    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | admin                            | address                  | 208  | 0      | 20    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | audit                            | address                  | 209  | 0      | 20    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | TOKEN_APPROVE                    | address                  | 210  | 0      | 20    | src/FeeVault.sol:FeeVault |
// |----------------------------------+--------------------------+------+--------+-------+---------------------------|
// | TOKEN_APPROVE_V3                 | address                  | 211  | 0      | 20    | src/FeeVault.sol:FeeVault |
// ╰----------------------------------+--------------------------+------+--------+-------+---------------------------╯


// 

// ╭------------------+----------------------------------------------+------+--------+-------+-------------------------------╮
// | Name             | Type                                         | Slot | Offset | Bytes | Contract                      |
// +=========================================================================================================================+
// | _initialized     | uint8                                        | 0    | 0      | 1     | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | _initializing    | bool                                         | 0    | 1      | 1     | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | __gap            | uint256[50]                                  | 1    | 0      | 1600  | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | _paused          | bool                                         | 51   | 0      | 1     | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | __gap            | uint256[49]                                  | 52   | 0      | 1568  | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | _owner           | address                                      | 101  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | __gap            | uint256[49]                                  | 102  | 0      | 1568  | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | _status          | uint256                                      | 151  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | __gap            | uint256[49]                                  | 152  | 0      | 1568  | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | adaptorInfo      | mapping(uint256 => address)                  | 201  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | approveProxy     | address                                      | 202  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | dexRouter        | address                                      | 203  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | payer            | address                                      | 204  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | receiver         | address                                      | 205  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | feeTo            | address                                      | 206  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | admin            | address                                      | 207  | 0      | 20    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | mpc              | mapping(address => bool)                     | 208  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | paidTx           | mapping(uint256 => mapping(bytes32 => bool)) | 209  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | receiveGasTx     | mapping(uint256 => mapping(bytes32 => bool)) | 210  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | sysRatio         | mapping(uint256 => uint256)                  | 211  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | sysAddressConfig | mapping(uint256 => address)                  | 212  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | thresholdConfig  | mapping(address => struct XBridge.Threshold) | 213  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | proxies          | mapping(address => bool)                     | 214  | 0      | 32    | contracts/XBridge.sol:XBridge |
// |------------------+----------------------------------------------+------+--------+-------+-------------------------------|
// | accessSelectorId | mapping(bytes4 => bool)                      | 215  | 0      | 32    | contracts/XBridge.sol:XBridge |
// ╰------------------+----------------------------------------------+------+--------+-------+-------------------------------╯


// ╭---------------------------+-----------------------------+------+--------+-------+-------------------------------------╮
// | Name                      | Type                        | Slot | Offset | Bytes | Contract                            |
// +=======================================================================================================================+
// | _initialized              | uint8                       | 0    | 0      | 1     | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | _initializing             | bool                        | 0    | 1      | 1     | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | __gap                     | uint256[50]                 | 1    | 0      | 1600  | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | _owner                    | address                     | 51   | 0      | 20    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | __gap                     | uint256[49]                 | 52   | 0      | 1568  | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | _status                   | uint256                     | 101  | 0      | 32    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | __gap                     | uint256[49]                 | 102  | 0      | 1568  | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | approveProxy              | address                     | 151  | 0      | 20    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | wNativeRelayer            | address                     | 152  | 0      | 20    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | priorityAddresses         | mapping(address => bool)    | 153  | 0      | 32    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | _dexRouterGap             | uint256[19]                 | 154  | 0      | 608   | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | admin                     | address                     | 173  | 0      | 20    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | slots_UNUSED              | uint256[6]                  | 174  | 0      | 192   | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | operator_UNUSED           | mapping(address => address) | 180  | 0      | 32    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | orderRemaining_UNUSED     | mapping(bytes32 => uint256) | 181  | 0      | 32    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | feeRateAndReceiver_UNUSED | uint256                     | 182  | 0      | 32    | contracts/8/DexRouter.sol:DexRouter |
// |---------------------------+-----------------------------+------+--------+-------+-------------------------------------|
// | _pmmRouterGap_UNUSED      | uint256[50]                 | 183  | 0      | 1600  | contracts/8/DexRouter.sol:DexRouter |
// ╰---------------------------+-----------------------------+------+--------+-------+-------------------------------------╯