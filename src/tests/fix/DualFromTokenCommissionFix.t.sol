pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {DexRouter, PMMLib} from "../../../contracts/8/DexRouter.sol";

contract DualFromTokenCommissionFixTest is Test {
    event CommissionFromTokenRecord(address fromTokenAddress, uint256 commissionAmount, address referrerAddress);

    address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant _ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;
    uint256 constant FROM_TOKEN_COMMISSION = 0x3ca20afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 constant TO_TOKEN_COMMISSION = 0x3ca20afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 constant FROM_TOKEN_COMMISSION_DUAL = 0x22220afc2aaa0000000000000000000000000000000000000000000000000000;
    uint256 constant TO_TOKEN_COMMISSION_DUAL = 0x22220afc2bbb0000000000000000000000000000000000000000000000000000;
    uint256 constant _TO_B_COMMISSION_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    address refer1 = 0x000000000000000000000000000000000000dEaD;
    address refer2 = 0x000000000000000000000000000000000000bEEF;
    uint256 rate1 = 0.0001 * 10 ** 9;
    uint256 rate2 = (2 * rate1) / 10;

    DexRouter public dexRouter = DexRouter(payable(0x2E1Dee213BA8d7af0934C49a23187BabEACa8764));
    address public fromToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address adaptor = 0x4E187d91C39686099fEAf2b57003BF524A2787C6;
    address assetTo = 0x4E187d91C39686099fEAf2b57003BF524A2787C6;
    bytes extraData =
        hex"000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4896646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019";
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        vm.etch(address(dexRouter), address(new DexRouter()).code);
    }

    function test_DualFromTokenCommissionFix() public {
        DexRouter.BaseRequest memory baseRequest;
        baseRequest.fromToken = uint256(uint160(fromToken));
        baseRequest.toToken = USDC;
        baseRequest.fromTokenAmount = 99;
        baseRequest.minReturnAmount = 0;
        baseRequest.deadLine = block.timestamp;
        uint256[] memory batchesAmount = new uint256[](1);
        batchesAmount[0] = 99;
        DexRouter.RouterPath[][] memory batches = new DexRouter.RouterPath[][](1);
        batches[0] = new DexRouter.RouterPath[](1);
        batches[0][0].mixAdapters = new address[](1);
        batches[0][0].mixAdapters[0] = adaptor;
        batches[0][0].assetTo = new address[](1);
        batches[0][0].assetTo[0] = assetTo;
        batches[0][0].rawData = new uint256[](1);
        batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(uint8(0x00), uint88(10000), address(0x96646936b91d6B9D7D0c47C496AfBF3D6ec7B6f8)))
        );
        batches[0][0].extraData = new bytes[](1);
        batches[0][0].extraData[0] = extraData;
        batches[0][0].fromToken = uint256(uint160(WETH));
        PMMLib.PMMSwapRequest[] memory extraData = new PMMLib.PMMSwapRequest[](0);
        bytes memory swapData = abi.encodeWithSelector(
            dexRouter.smartSwapByOrderId.selector, 1, baseRequest, batchesAmount, batches, extraData
        );
        bytes memory data = bytes.concat(swapData, _getCommissionInfo(true, true, true, _ETH));
        vm.expectEmit(true, true, true, true);
        emit CommissionFromTokenRecord(_ETH, 0, refer1);
        vm.expectEmit(true, true, true, true);
        emit CommissionFromTokenRecord(_ETH, 0, refer2);
        address(dexRouter).call{value: 99}(data);
    }

    function _getCommissionInfo(bool _hasNextRefer, bool _isToB, bool _isFrom, address _token)
        internal
        view
        returns (bytes memory data)
    {
        uint256 flag = _isFrom
            ? (_hasNextRefer ? FROM_TOKEN_COMMISSION_DUAL : FROM_TOKEN_COMMISSION)
            : (_hasNextRefer ? TO_TOKEN_COMMISSION_DUAL : TO_TOKEN_COMMISSION);

        bytes32 first = bytes32(flag + uint256(rate1 << 160) + uint256(uint160(refer1)));
        bytes32 middle = bytes32(abi.encodePacked(uint8(_isToB ? 0x80 : 0), uint88(0), _token));
        bytes32 last = bytes32(flag + uint256(rate2 << 160) + uint256(uint160(refer2)));

        return _hasNextRefer ? abi.encode(last, middle, first) : abi.encode(middle, first);
    }
}
