// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "../common/Permit2Helper.t.sol";
import "@dex/interfaces/IPermit2.sol";

contract FromTokenCommissionTest is TrimAndCommissionTestBase, Permit2Helper {
    uint256 public arnaudPrivateKey = 11111111111111111111;

    // ==================== Test fromToken commission with multi transfer modes ===================
    // (1) WETH->USDT, 3fromCommission, no-toBCommission, legacy mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToC_legacy() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (2) WETH->USDT, 3fromCommission, toBCommission, legacy mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_legacy() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_LEGACY)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_LEGACY);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (3) WETH->USDT, 3fromCommission, no-toBCommission, direct mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToC_direct() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_DIRECT)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_DIRECT);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (4) WETH->USDT, 3fromCommission, toBCommission, direct mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_direct() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_DIRECT)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_DIRECT);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (5) WETH->USDT, 3fromCommission, no-toBCommission, permit2 allowance mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToC_permit2Allowance() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_ALLOWANCE)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_PERMIT2_ALLOWANCE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (6) WETH->USDT, 3fromCommission, toBCommission, permit2 allowance mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_permit2Allowance() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_ALLOWANCE)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_PERMIT2_ALLOWANCE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        bytes memory data = bytes.concat(swapData, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (7) WETH->USDT, 3fromCommission, no-toBCommission, permit2 signature mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToC_permit2Signature() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, false, 3);
        uint256[] memory amounts = new uint256[](3 + 1); // swapAmount, all ToC commission amounts
        amounts[0] = 2 * 10 ** 18;
        for (uint256 i = 1; i < amounts.length; i++) {
            amounts[i] = 1 * 10 ** 18;
        }
        bytes memory permit2Info = _generatePermit2InfoBatch(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (8) WETH->USDT, 3fromCommission, toBCommission, permit2 signature mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_permit2Signature() tokenLogAndCheck3(WETH, USDT, 2 * 10 ** 18, false, false, true, 3, _MODE_PERMIT2_SIGNATURE)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData(_MODE_PERMIT2_SIGNATURE);
        bytes memory commissionData = _generateMultipleCommissionData(true, WETH, true, 3);
        uint256[] memory amounts = new uint256[](1); // swapAmount + all ToB commission amounts
        amounts[0] = 3 * 10 ** 18;
        bytes memory permit2Info = _generatePermit2InfoBatch(WETH, amounts);
        bytes memory data = bytes.concat(swapData, permit2Info, commissionData);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // (9) WETH->USDT, 3fromCommission, no-toBCommission, by invest mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToC_byInvest() public {

    }

    // (10) WETH->USDT, 3fromCommission, toBCommission, by invest mode
    function test_fromTokenCommission_WETH2USDT_3fromCommissionToB_byInvest() public {

    }


    // ==================== Internal Functions ====================
    function _generateWETH2USDTDagSwapData(uint256 mode) internal view returns (bytes memory) {
        // baseRequest
        DexRouter.BaseRequest memory baseRequest = _generateBaseRequest(WETH, USDT, oneEther);
        // batches
        DexRouter.RouterPath[] memory path = new DexRouter.RouterPath[](1);
        path[0].mixAdapters = new address[](1);
        path[0].mixAdapters[0] = address(UniversalUniV3Adapter);
        path[0].assetTo = new address[](1);
        path[0].assetTo[0] = address(UniversalUniV3Adapter);
        path[0].rawData = new uint256[](1);
        path[0].rawData[0] = uint256(bytes32(abi.encodePacked(uint64(0x00), uint8(0), uint8(1), uint16(10000), address(WETH_USDT_UNIV3))));
        path[0].extraData = new bytes[](1);
        path[0].extraData[0] = abi.encode(0, abi.encode(WETH, USDT, 0));
        path[0].fromToken = uint256(uint160(WETH)) | mode;

        return abi.encodeWithSelector(
            DexRouter.dagSwapTo.selector,
            0, arnaud, baseRequest, path
        );
    }

    function _generateWETH2USDTSmartSwapData(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapData(
            WETH,
            USDT,
            oneEther,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(WETH, USDT, 0)),
            mode
        );
    }

    function _generateUSDT2WETHSmartSwapData(uint256 mode) internal view returns (bytes memory) {
        return _generateSmartSwapData(
            USDT,
            WETH,
            1000 * 10 ** 6,
            address(UniversalUniV3Adapter),
            address(UniversalUniV3Adapter),
            false,
            address(WETH_USDT_UNIV3),
            abi.encode(0, abi.encode(USDT, WETH, 0)),
            mode
        );
    }

    function _generateSmartSwapData(
        address fromToken,
        address toToken,
        uint256 fromTokenAmount,
        address assetTo,
        address adapter,
        bool isReverse,
        address poolAddress,
        bytes memory extraData,
        uint256 mode
    ) internal view returns (bytes memory) {
        SwapInfo memory swapInfo;
        // baseRequest
        swapInfo.baseRequest = _generateBaseRequest(fromToken, toToken, fromTokenAmount);
        // batchesAmount
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = fromTokenAmount;
        // batches
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = adapter;
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = assetTo;
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(bytes32(abi.encodePacked(uint8(isReverse ? 0x80 : 0x00), uint88(10000), poolAddress)));
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = extraData;
        swapInfo.batches[0][0].fromToken = uint256(uint160(fromToken == ETH ? WETH : fromToken)) | mode;
        // extraData
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        return abi.encodeWithSelector(
            DexRouter.smartSwapTo.selector,
            swapInfo.orderId, arnaud, swapInfo.baseRequest, swapInfo.batchesAmount, swapInfo.batches, swapInfo.extraData
        );
    }

    function _generatePermit2Info(
        address token,
        uint256 amount
    ) internal view returns (bytes memory) {
        IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
            token, // token
            amount, // amount
            2, // nonce
            2524579200 // deadline 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            11111111111111111111, // private key
            address(dexRouter), // spender
            Permit2EthDomainSeperator
        );

        bytes memory permit2Info = _buildPermit2InfoUnified(
            permit.permitted.amount,
            permit.nonce,
            permit.deadline,
            arnaud,
            signature
        );

        return permit2Info;
    }

    function _generatePermit2InfoBatch(
        address token,
        uint256[] memory amounts
    ) internal view returns (bytes memory) {
        IPermit2.PermitBatchTransferFrom memory permit = getPermitBatchTransferFrom(
            token,
            amounts,
            2, // nonce
            2524579200 // deadline 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitBatchTransferSignature(
            permit,
            arnaudPrivateKey,
            address(dexRouter),
            Permit2EthDomainSeperator
        );
        bytes memory permit2Info = _buildPermit2InfoUnifiedBatch(
            amounts,
            permit.nonce,
            permit.deadline,
            arnaud,
            signature
        );

        return permit2Info;
    }
}