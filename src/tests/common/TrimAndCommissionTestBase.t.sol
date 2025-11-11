// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@dex/DexRouter.sol";
import "@dex/TokenApprove.sol";
import "@dex/TokenApproveProxy.sol";
import "@dex/utils/WNativeRelayer.sol";
import "@dex/libraries/SafeERC20.sol";
import "@dex/adapter/UniAdapter.sol";
import "./CommissionHelper.t.sol";
import "./TrimHelper.t.sol";

interface ISafeMoon {
    function owner() external view returns (address);
    function updateBuyFees(uint256 _marketingFee, uint256 _liquidityFee, uint256 _devFee) external;
    function updateSellFees(uint256 _marketingFee, uint256 _liquidityFee, uint256 _devFee) external;
    function buyTotalFees() external view returns (uint256);
    function sellTotalFees() external view returns (uint256);
}

contract TrimAndCommissionTestBase is Test, CommissionHelper, TrimHelper {
    // tokens
    address constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // decimals=18
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // decimals=6
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // decimals=6
    address constant SAFEMOON = 0xE253Be149830bcE1a6Af3BE399f3a952eabe127E; // Tax token, UniswapV2 pool always takes fee for sell and buy, decimals=18

    // pools
    address constant WETH_USDT_UNIV2 = 0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852;
    address constant WETH_USDT_UNIV3 = 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36;
    address constant USDC_WETH_UNIV2 = 0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc;
    address constant USDC_WETH_UNIV3 = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;
    address constant WETH_SAFEMOON_UNIV2 = 0xd2e185A9076d33BD76cE548961EE6E9cB700BA17;

    // users
    address public admin = vm.rememberKey(1);
    address public arnaud = vm.rememberKey(11111111111111111111);
    address public trimAddress = vm.rememberKey(22222222222222222222);
    address public chargeAddress = vm.rememberKey(33333333333333333333);
    address[] public referrerAddresses = new address[](8);
    
    // contracts
    DexRouter public dexRouter;
    TokenApprove tokenApprove = TokenApprove(0x40aA958dd87FC8305b97f2BA922CDdCa374bcD7f); // ETH
    TokenApproveProxy tokenApproveProxy = TokenApproveProxy(0x70cBb871E8f30Fc8Ce23609E9E0Ea87B6b222F58); // ETH
    WNativeRelayer wNativeRelayer = WNativeRelayer(payable(0x5703B683c7F928b721CA95Da988d73a3299d4757)); // ETH

    address constant UniversalUniV3Adapter = 0x6747BcaF9bD5a5F0758Cbe08903490E45DdfACB5;
    address public UniV2Adapter;

    uint256 public oneEther = 1 * 10 ** 18;

    struct SwapInfo {
        uint256 orderId;
        DexRouter.BaseRequest baseRequest;
        uint256[] batchesAmount;
        DexRouter.RouterPath[][] batches;
        PMMLib.PMMSwapRequest[] extraData;
    }

    constructor() {
        referrerAddresses[0] = vm.rememberKey(44444444444444000000);
        referrerAddresses[1] = vm.rememberKey(44444444444444111111);
        referrerAddresses[2] = vm.rememberKey(44444444444444222222);
        referrerAddresses[3] = vm.rememberKey(44444444444444333333);
        referrerAddresses[4] = vm.rememberKey(44444444444444444444);
        referrerAddresses[5] = vm.rememberKey(44444444444444555555);
        referrerAddresses[6] = vm.rememberKey(44444444444444666666);
        referrerAddresses[7] = vm.rememberKey(44444444444444777777);
    }

    modifier tokenLogAndCheck(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        bool trimShouldReceive,
        bool chargeShouldReceive,
        bool isFromCommission,
        bool referrer1ShouldReceive,
        bool referrer2ShouldReceive
    ) {
        vm.startPrank(arnaud);
        console2.log("User arnaud:", arnaud);
        if (_fromToken == ETH) {
            deal(address(arnaud), _amount);
        } else {
            deal(_fromToken, arnaud, _amount);
            SafeERC20.safeApprove(IERC20(_fromToken), address(tokenApprove), _amount);
        }
        address[] memory tokens = new address[](2);
        tokens[0] = _fromToken;
        tokens[1] = _toToken;
        _beforeSwapCheck(tokens);
        _;
        bool[] memory referrerShouldReceive = new bool[](2);
        referrerShouldReceive[0] = referrer1ShouldReceive;
        referrerShouldReceive[1] = referrer2ShouldReceive;
        _afterSwapCheck(tokens, trimShouldReceive, chargeShouldReceive, isFromCommission, referrerShouldReceive);
        vm.stopPrank();
    }

    modifier tokenLogAndCheck2(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        bool trimShouldReceive,
        bool chargeShouldReceive,
        bool isFromCommission,
        uint256 referrerShouldReceiveNum
    ) {
        vm.startPrank(arnaud);
        console2.log("User arnaud:", arnaud);
        if (_fromToken == ETH) {
            deal(address(arnaud), _amount);
        } else {
            deal(_fromToken, arnaud, _amount);
            SafeERC20.safeApprove(IERC20(_fromToken), address(tokenApprove), _amount);
        }
        address[] memory tokens = new address[](2);
        tokens[0] = _fromToken;
        tokens[1] = _toToken;
        _beforeSwapCheck(tokens);
        _;
        bool[] memory referrerShouldReceive = new bool[](MAX_COMMISSION_MULTIPLE_NUM);
        for (uint256 i = 0; i < referrerShouldReceiveNum; i++) {
            referrerShouldReceive[i] = true;
        }
        _afterSwapCheck(tokens, trimShouldReceive, chargeShouldReceive, isFromCommission, referrerShouldReceive);
        vm.stopPrank();
    }

    function _beforeSwapCheck(
        address[] memory tokens
    ) internal view {
        console2.log("========== before swap ==========");
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == ETH) {
                console2.log(
                    "arnaud ETH balance before: %d",
                    address(arnaud).balance
                );
                uint256 trimBalance = address(trimAddress).balance;
                console2.log("trim ETH balance before: %d", trimBalance);
                require(trimBalance == 0, "trim ETH balance before should be 0");
                uint256 chargeBalance = address(chargeAddress).balance;
                console2.log("charge ETH balance before: %d", chargeBalance);
                require(chargeBalance == 0, "charge ETH balance before should be 0");
                for (uint256 j = 0; j < referrerAddresses.length; j++) {
                    uint256 referrerBalance = address(referrerAddresses[j]).balance;
                    console2.log("referrer%d ETH balance before: %d", j, referrerBalance);
                    require(referrerBalance == 0, "referrer ETH balance before should be 0");
                }
            } else {
                console2.log(
                    "%s balance before: %d",
                    IERC20(token).symbol(),
                    IERC20(token).balanceOf(address(arnaud))
                );
                uint256 trimBalance = IERC20(token).balanceOf(address(trimAddress));
                console2.log("trim %s balance before: %d", IERC20(token).symbol(), trimBalance);
                require(trimBalance == 0, "trim balance before should be 0");
                uint256 chargeBalance = IERC20(token).balanceOf(address(chargeAddress));
                console2.log("charge %s balance before: %d", IERC20(token).symbol(), chargeBalance);
                require(chargeBalance == 0, "charge balance before should be 0");
                for (uint256 j = 0; j < referrerAddresses.length; j++) {
                    uint256 referrerBalance = IERC20(token).balanceOf(address(referrerAddresses[j]));
                    console2.log("referrer%d %s balance before: %d", j, IERC20(token).symbol(), referrerBalance);
                    require(referrerBalance == 0, "referrer balance before should be 0");
                }
            }
        }
    }

    function _afterSwapCheck(
        address[] memory tokens,
        bool trimShouldReceive,
        bool chargeShouldReceive,
        bool isFromCommission,
        bool[] memory referrerShouldReceive
    ) internal view {
        console2.log("========== after swap ==========");
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            if (token == ETH) {
                console2.log("arnaud ETH balance after: %d", address(arnaud).balance);
                uint256 trimBalance = address(trimAddress).balance;
                console2.log("trim ETH balance after: %d", trimBalance);
                // Only when token is toToken, then check with shouldReceive flag.
                if (i == 1) {
                    require(
                        (trimShouldReceive && trimBalance > 0) || (!trimShouldReceive && trimBalance == 0),
                        "trim1 ETH balance error after swap"
                    );
                }
                uint256 chargeBalance = address(chargeAddress).balance;
                console2.log("charge ETH balance after: %d", chargeBalance);
                if (i == 1) {
                    require(
                        (chargeShouldReceive && chargeBalance > 0) || (!chargeShouldReceive && chargeBalance == 0),
                        "charge ETH balance error after swap"
                    );
                }
                for (uint256 j = 0; j < referrerShouldReceive.length; j++) {
                    uint256 referrerBalance = address(referrerAddresses[j]).balance;
                    console2.log("referrer%d ETH balance after: %d", j, referrerBalance);
                    // Only when isFromCommission==true and token is fromToken, or isFromCommission==false and token is toToken, then check with shouldReceive flag.
                    if ((i == 0 && isFromCommission) || (i == 1 && !isFromCommission)) {
                        require(
                            (referrerShouldReceive[j] && referrerBalance > 0) || (!referrerShouldReceive[j] && referrerBalance == 0),
                            "referrer ETH balance error after swap"
                        );
                    }
                }
            } else {
                console2.log("%s balance after: %d", IERC20(token).symbol(), IERC20(token).balanceOf(address(arnaud)));
                uint256 trimBalance = IERC20(token).balanceOf(address(trimAddress));
                console2.log("trim %s balance after: %d", IERC20(token).symbol(), trimBalance);
                if (i == 1) {
                    require(
                        (trimShouldReceive && trimBalance > 0) || (!trimShouldReceive && trimBalance == 0),
                        "trim balance error after swap"
                    );
                }
                uint256 chargeBalance = IERC20(token).balanceOf(address(chargeAddress));
                console2.log("charge %s balance after: %d", IERC20(token).symbol(), chargeBalance);
                if (i == 1) {
                    require(
                        (chargeShouldReceive && chargeBalance > 0) || (!chargeShouldReceive && chargeBalance == 0),
                        "charge balance error after swap"
                    );
                }
                for (uint256 j = 0; j < referrerShouldReceive.length; j++) {
                    uint256 referrerBalance = IERC20(token).balanceOf(address(referrerAddresses[j]));
                    console2.log("referrer%d %s balance after: %d", j, IERC20(token).symbol(), referrerBalance);
                    // Only when isFromCommission==true and token is fromToken, or isFromCommission==false and token is toToken, then check with shouldReceive flag.
                    if ((i == 0 && isFromCommission) || (i == 1 && !isFromCommission)) {
                        require(
                            (referrerShouldReceive[j] && referrerBalance > 0) || (!referrerShouldReceive[j] && referrerBalance == 0),
                            "referrer balance error after swap"
                        );
                    }
                }
            }
        }
    }

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23293873); // 2025.9.5 10:18
        vm.startPrank(admin);
        UniV2Adapter = address(new UniAdapter());
        dexRouter = new DexRouter();
        vm.stopPrank();
        address wNativeRelayerOwner = wNativeRelayer.owner();
        vm.startPrank(wNativeRelayerOwner);
        tokenApproveProxy.addProxy(address(dexRouter));
        address[] memory whitelistedCallers = new address[](1);
        whitelistedCallers[0] = address(dexRouter);
        wNativeRelayer.setCallerOk(whitelistedCallers, true);
        vm.stopPrank();
        address safeMoonOwner = ISafeMoon(SAFEMOON).owner();
        vm.startPrank(safeMoonOwner);
        ISafeMoon(SAFEMOON).updateBuyFees(10, 0, 0);
        ISafeMoon(SAFEMOON).updateSellFees(20, 0, 0);
        vm.stopPrank();
        // console2.log("safeMoon buy fees: %d", ISafeMoon(SAFEMOON).buyTotalFees());
        // console2.log("safeMoon sell fees: %d", ISafeMoon(SAFEMOON).sellTotalFees());
    }

    // ==================== Internal Functions ====================
    function _generateBaseRequest(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) internal view returns (DexRouter.BaseRequest memory baseRequest) {
        baseRequest.fromToken = uint256(uint160(_fromToken));
        baseRequest.toToken = _toToken;
        baseRequest.fromTokenAmount = _amount;
        baseRequest.minReturnAmount = 0;
        baseRequest.deadLine = block.timestamp + 1000;
    }

    function _generate1TrimOnlyTrimData() internal view returns (bytes memory) {
        return _buildTrimInfoUnified(
            50, // trimRate 5%
            trimAddress, // trimAddress
            100, // expectAmountOut 100, but usually the trimAmount will be the allowedMaxTrimAmount cause the expectAmountOut is too small
            0, // chargeRate 0%, all for trim
            address(0), // chargeAddress,
            false // isToBTrim
        );
    }

    function _generate1TrimOnlyChargeData() internal view returns (bytes memory) {
        return _buildTrimInfoUnified(
            50, // trimRate 5%
            address(0), // trimAddress
            100, // expectAmountOut 100, but usually the trimAmount will be the allowedMaxTrimAmount cause the expectAmountOut is too small
            1000, // chargeRate 100%, all for charge
            chargeAddress, // chargeAddress,
            false // isToBTrim
        );
    }

    function _generate2TrimData() internal view returns (bytes memory) {
        return _buildTrimInfoUnified(
            50, // trimRate 5%
            trimAddress, // trimAddress
            100, // expectAmountOut 100, but usually the trimAmount will be the allowedMaxTrimAmount cause the expectAmountOut is too small
            400, // chargeRate 40% of trimAmount (400 / 1000)
            chargeAddress, // chargeAddress,
            true // isToBTrim
        );
    }

    function _generate1CommissionData(bool isFromTokenCommission, address token) internal view returns (bytes memory) {
        uint256[] memory commissionRates_ = new uint256[](1);
        commissionRates_[0] = 1000000;
        address[] memory referrerAddresses_ = new address[](1);
        referrerAddresses_[0] = referrerAddresses[0];
        return _buildCommissionInfoUnified(
            isFromTokenCommission, // isFromTokenCommission
            !isFromTokenCommission, // isToTokenCommission
            token, // token
            false, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
    }

    function _generate2CommissionData(bool isFromTokenCommission, address token) internal view returns (bytes memory) {
        uint256[] memory commissionRates_ = new uint256[](2);
        commissionRates_[0] = 1000000;
        commissionRates_[1] = 1000000;
        address[] memory referrerAddresses_ = new address[](2);
        referrerAddresses_[0] = referrerAddresses[0];
        referrerAddresses_[1] = referrerAddresses[1];
        return _buildCommissionInfoUnified(
            isFromTokenCommission, // isFromTokenCommission
            !isFromTokenCommission, // isToTokenCommission
            token, // token
            false, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
    }

    function _generateMultipleCommissionData(bool isFromTokenCommission, address token, bool isToBCommission, uint256 referrerNum) internal view returns (bytes memory) {
        uint256[] memory commissionRates_ = new uint256[](referrerNum);
        address[] memory referrerAddresses_ = new address[](referrerNum);
        for (uint256 i = 0; i < referrerNum; i++) {
            commissionRates_[i] = 1000000;
            referrerAddresses_[i] = referrerAddresses[i];
        }
        return _buildCommissionInfoUnified(
            isFromTokenCommission, // isFromTokenCommission
            !isFromTokenCommission, // isToTokenCommission
            token, // token
            isToBCommission, // isToBCommission
            commissionRates_,
            referrerAddresses_
        );
    }
}