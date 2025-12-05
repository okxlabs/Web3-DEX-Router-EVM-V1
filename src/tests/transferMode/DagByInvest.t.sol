// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@dex/DexRouter.sol";
import "@dex/TokenApprove.sol";
import "@dex/TokenApproveProxy.sol";
import "@dex/adapter/DnyFeeAdapter.sol";
import "@dex/libraries/CommonUtils.sol";
import {PMMLib} from "@dex/libraries/PMMLib.sol";
import {Test, console2} from "forge-std/test.sol";

contract DagByInvestTest is Test ,CommonUtils {
    DexRouter dexRouter;
    TokenApproveProxy tokenApproveProxy = TokenApproveProxy(0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58);
    TokenApprove tokenApprove = TokenApprove(0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f);
    address tokenApproveProxyAdmin = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address adapter;
    address pool = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc; //WETH-USDC

    function setUp() public {
        vm.createSelectFork("https://rpc.mevblocker.io/noreverts");
        dexRouter = new DexRouter();
        vm.startPrank(tokenApproveProxyAdmin);
        tokenApproveProxy.addProxy(address(dexRouter));
        vm.stopPrank();
        adapter = address(new DnyFeeAdapter());
    }

    function test_dagByInvest() public {
        DexRouter.BaseRequest memory baseRequest;
        baseRequest.fromToken = uint256(uint160(address(_ETH)));
        baseRequest.toToken = address(USDC);
        baseRequest.fromTokenAmount = 1 ether;
        baseRequest.minReturnAmount = 0;
        baseRequest.deadLine = block.timestamp;

        uint256[] memory batchesAmount = new uint256[](1);
        batchesAmount[0] = 1 ether;

        DexRouter.RouterPath[] memory batches = new DexRouter.RouterPath[](1);
        batches[0].mixAdapters = new address[](1);
        batches[0].mixAdapters[0] = address(adapter);
        batches[0].assetTo = new address[](1);
        batches[0].assetTo[0] = address(pool);
        batches[0].rawData = new uint256[](1);
        batches[0].rawData[0] = _configPair(pool);
        batches[0].extraData = new bytes[](1);
        batches[0].extraData[0] = abi.encode(30);
        batches[0].fromToken = uint256(uint160(address(WETH))) | _MODE_BY_INVEST;
        dexRouter.dagSwapTo{value: 1 ether}(uint(0), address(this), baseRequest, batches);
    }
    function test_dagByInvest_weth() public {
        DexRouter.BaseRequest memory baseRequest;
        baseRequest.fromToken = uint256(uint160(address(WETH)));
        baseRequest.toToken = address(USDC);
        baseRequest.fromTokenAmount = 1 ether;
        baseRequest.minReturnAmount = 0;
        baseRequest.deadLine = block.timestamp;

        uint256[] memory batchesAmount = new uint256[](1);
        batchesAmount[0] = 1 ether;

        DexRouter.RouterPath[] memory batches = new DexRouter.RouterPath[](1);
        batches[0].mixAdapters = new address[](1);
        batches[0].mixAdapters[0] = address(adapter);
        batches[0].assetTo = new address[](1);
        batches[0].assetTo[0] = address(pool);
        batches[0].rawData = new uint256[](1);
        batches[0].rawData[0] = _configPair(pool);
        batches[0].extraData = new bytes[](1);
        batches[0].extraData[0] = abi.encode(30);
        batches[0].fromToken = uint256(uint160(address(WETH))) | _MODE_BY_INVEST;
        deal(WETH, address(dexRouter), 1 ether);
        dexRouter.dagSwapTo(uint(0), address(this), baseRequest, batches);
    }

    function _configPair(address pool) internal view returns (uint256) {
        uint addr_ = uint(uint160(pool));
        uint weight = 10000 << 160;
        uint inputIndex = 0 << 184;
        uint outputIndex = 1 << 176;
        uint isZeroForOne = uint(_REVERSE_MASK);
        return addr_ + weight + inputIndex + outputIndex + isZeroForOne;
    }
}
