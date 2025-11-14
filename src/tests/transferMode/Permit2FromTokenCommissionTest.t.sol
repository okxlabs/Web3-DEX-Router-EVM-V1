// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";
import "../common/Permit2Helper.t.sol";
import "@dex/interfaces/IPermit2.sol";

contract Permit2TokenTransfer {
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    struct Permit2Info {
        IPermit2.PermitTransferFrom permit;
        address owner;
        bytes signature;
    }

    function permit2TransferFrom(
        Permit2Info memory permit2Info,
        address to,
        uint256 amount
    ) public {
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: to,
            requestedAmount: amount
        });
        IPermit2(PERMIT2).permitTransferFrom(permit2Info.permit, transferDetails, permit2Info.owner, permit2Info.signature);
    }

    function permit2TransferFromAssembly(
        Permit2Info memory permit2Info,
        address to,
        uint256 amount
    ) public {
        assembly ("memory-safe") {

        }
    }
}

contract Permit2FromTokenCommissionTest is TrimAndCommissionTestBase, Permit2Helper {
    Permit2TokenTransfer public permit2Transfer;
    uint256 public arnaudPrivateKey = 11111111111111111111;

    function setUp() override public {
        permit2Transfer = new Permit2TokenTransfer();
        super.setUp();
    }

    function test_getCommissionAndTrimInfo() tokenLogAndCheck(WETH, USDT, oneEther, false, false, false, false, false)  public {
        bytes memory swapData = _generateWETH2USDTDagSwapData();
        bytes memory permit2Info = _generatePermit2Info();
        bytes memory data = bytes.concat(swapData, permit2Info);
        (bool success, ) = address(dexRouter).call(data);
        require(success, "call failed");
    }

    // TODO
    // 1. 编写辅助合约，测试assembly下如何调用Permit2的permitTransferFrom方法
    // 2. 在CommissionLib中添加fromToken分佣多模式转账的的逻辑，调整dag接口支持fromToken分佣多模式转账

    function test_permit2TransferFrom() public {
        deal(WETH, arnaud, 100 * 10 ** 18);
        console2.log("arnaud:", arnaud);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));

        vm.startPrank(arnaud);
        IERC20(WETH).approve(permit2Transfer.PERMIT2(), type(uint256).max);
        IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
            WETH,
            10 * 10 ** 18,
            0,
            2524579200 // 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            arnaudPrivateKey,
            address(permit2Transfer),
            Permit2EthDomainSeperator
        );
        Permit2TokenTransfer.Permit2Info memory permit2Info = Permit2TokenTransfer.Permit2Info({
            permit: permit,
            owner: arnaud,
            signature: signature
        });
        permit2Transfer.permit2TransferFrom(permit2Info, bob, 1 * 10 ** 18);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));
    }


    function test_permit2TransferFromAssembly() public {
        deal(WETH, arnaud, 100 * 10 ** 18);
        console2.log("arnaud:", arnaud);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));

        vm.startPrank(arnaud);
        IERC20(WETH).approve(permit2Transfer.PERMIT2(), type(uint256).max);
        IPermit2.PermitTransferFrom memory permit = getPermitTransferFrom(
            WETH,
            10 * 10 ** 18,
            0,
            2524579200 // 2050-01-01 00:00:00
        );
        bytes memory signature = getPermitTransferSignature(
            permit,
            arnaudPrivateKey,
            address(permit2Transfer),
            Permit2EthDomainSeperator
        );
        Permit2TokenTransfer.Permit2Info memory permit2Info = Permit2TokenTransfer.Permit2Info({
            permit: permit,
            owner: arnaud,
            signature: signature
        });
        permit2Transfer.permit2TransferFromAssembly(permit2Info, bob, 1 * 10 ** 18);
        console2.log("arnaud WETH balance:", IERC20(WETH).balanceOf(arnaud));
        console2.log("bob WETH balance:", IERC20(WETH).balanceOf(bob));
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