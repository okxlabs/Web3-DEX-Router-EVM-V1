// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

contract MultiCall {
    function multiCall(address[] calldata targets, uint256[] calldata values, bytes[] calldata datas) external payable {
        for (uint256 i = 0; i < targets.length; i++) {
            (bool success_, ) = targets[i].call{value: values[i]}(datas[i]);
            require(success_, "call failed");
        }
    }
}

contract MultiCallTrimTest is TrimAndCommissionTestBase {
    MultiCall multiCall;

    modifier tokenLog() {
        deal(arnaud, 5 * 10 ** 18);
        console2.log("eth balance of arnaud before: %d", address(arnaud).balance);
        console2.log("eth balance of referrer1: %d", address(referrerAddresses[0]).balance);
        console2.log("eth balance of referrer2: %d", address(referrerAddresses[1]).balance);
        console2.log("eth balance of trim: %d", address(trimAddress).balance);
        console2.log("eth balance of charge: %d", address(chargeAddress).balance);
        console2.log("USDT balance of arnaud: %d", IERC20(USDT).balanceOf(address(arnaud)));
        console2.log("USDT balance of referrer1: %d", IERC20(USDT).balanceOf(address(referrerAddresses[0])));
        console2.log("USDT balance of referrer2: %d", IERC20(USDT).balanceOf(address(referrerAddresses[1])));
        console2.log("USDT balance of trim: %d", IERC20(USDT).balanceOf(address(trimAddress)));
        console2.log("USDT balance of charge: %d", IERC20(USDT).balanceOf(address(chargeAddress)));
        _;
        console2.log("eth balance of arnaud after: %d", address(arnaud).balance);
        console2.log("eth balance of referrer1 after: %d", address(referrerAddresses[0]).balance);
        console2.log("eth balance of referrer2 after: %d", address(referrerAddresses[1]).balance);
        console2.log("eth balance of trim after: %d", address(trimAddress).balance);
        console2.log("eth balance of charge after: %d", address(chargeAddress).balance);
        console2.log("USDT balance of arnaud after: %d", IERC20(USDT).balanceOf(address(arnaud)));
        console2.log("USDT balance of referrer1 after: %d", IERC20(USDT).balanceOf(address(referrerAddresses[0])));
        console2.log("USDT balance of referrer2 after: %d", IERC20(USDT).balanceOf(address(referrerAddresses[1])));
        console2.log("USDT balance of trim after: %d", IERC20(USDT).balanceOf(address(trimAddress)));
        console2.log("USDT balance of charge after: %d", IERC20(USDT).balanceOf(address(chargeAddress)));
    }

    function setUp() public override {
        multiCall = new MultiCall();
        super.setUp();
    }

    function test_multiCall() public tokenLog {
        vm.startPrank(arnaud);
        bytes memory swapData = _generateETH2USDTSmartSwapData();
        bytes memory commissionData1 = _generate1CommissionData(true, ETH); // fromTokenCommission
        bytes memory commissionData2 = _generate1CommissionData(false, USDT); // toTokenCommission
        bytes memory trimData1 = _generate1TrimOnlyTrimData();
        bytes memory trimData2 = _generate1TrimOnlyChargeData();
        
        address[] memory targets = new address[](3);
        targets[0] = address(dexRouter);
        targets[1] = address(dexRouter);
        targets[2] = address(dexRouter);
        uint256[] memory values = new uint256[](3);
        values[0] = 1.2 * 10 ** 18;
        values[1] = 1.2 * 10 ** 18;
        values[2] = 1.2 * 10 ** 18;
        bytes[] memory datas = new bytes[](3);
        datas[0] = bytes.concat(swapData, commissionData1);
        datas[1] = bytes.concat(swapData, trimData1, commissionData2);
        datas[2] = bytes.concat(swapData, trimData2, commissionData1);

        bytes memory allData = abi.encodeWithSelector(
            MultiCall.multiCall.selector,
            targets,
            values,
            datas
        );

        // log calldata
        // console2.logBytes(allData);

        (bool success, ) = address(multiCall).call{value: 5 * 10 ** 18}(allData);
        require(success, "call failed");
        vm.stopPrank();
    }

    // ==================== Internal Functions ====================
    function _generateETH2USDTSmartSwapData() internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(ETH, USDT, oneEther);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = oneEther;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(UniversalUniV3Adapter);
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(WETH_USDT_UNIV3))));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(0, abi.encode(WETH, USDT, 0));
        swapInfo.batches[0][0].fromToken = uint256(uint160(WETH));
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        ); 
    }
}