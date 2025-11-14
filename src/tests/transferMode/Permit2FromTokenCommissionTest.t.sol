// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "../common/Permit2Helper.t.sol";

contract Permit2FromTokenCommissionTest is TrimAndCommissionTestBase, Permit2Helper {
    function test_getCommissionAndTrimInfo() tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData();
        bytes memory permit2Info = _generatePermit2Info();
        bytes memory data = bytes.concat(swapData, permit2Info);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // ==================== Internal Functions ====================
    function _generateWETH2USDTDagSwapData() internal view returns (bytes memory) {
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
        path[0].fromToken = uint256(uint160(WETH));

        return abi.encodeWithSelector(
            DexRouter.dagSwapTo.selector,
            0, arnaud, baseRequest, path
        );
    }

    function _generatePermit2Info() internal view returns (bytes memory) {
        IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH on eth
            1000000000000000000, // 1 WETH
            1,
            2524579200 // 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            0x12341234, // private key
            0xF6801D319497789f934ec7F83E142a9536312B08, // spender
            Permit2EthDomainSeperator
        );

        bytes memory permit2Info = _buildPermit2InfoUnified(
            permit.nonce,
            permit.deadline,
            permit.permitted.amount,
            0xA229781d40864011729C753EAc24a772890fF527,
            signature
        );

        return permit2Info;
    }
}