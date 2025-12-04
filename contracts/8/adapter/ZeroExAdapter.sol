// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IZeroEx.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeMath.sol";

contract ZeroExAdapter is IAdapter {
    using SafeMath for uint256;
 
    address public EXCHANGE_PROXY = 0xDef1C0ded9bec7F1a1670819833240f027b25EfF ;
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public  WETH_ADDRESS;
    address internal ADMIN;

    constructor(
        address _weth
    )  {
        ADMIN = msg.sender;
        WETH_ADDRESS = _weth;
    }

    modifier onlyAdmin() {
        if (msg.sender != ADMIN) revert("only admin");
        _;
    }
    
    function _rfqSwap(
        address to,
        address ,
        bytes memory moreInfo
    ) internal {
        ( address fromToken, address toToken, LimitOrder memory order, Signature memory makerSignature ) = abi.decode (
            moreInfo,
            ( address, address,  LimitOrder, Signature)
        );

        // approve to exchange proxy adapterBalance
        uint256 adapterBalance = IERC20(fromToken).balanceOf(address(this));
        SafeERC20.safeApprove(IERC20(fromToken), EXCHANGE_PROXY, adapterBalance);  


        // check limitorder status
        OrderInfo memory orderInfo = IZeroEx(EXCHANGE_PROXY).getLimitOrderInfo(order);
        if (orderInfo.status != OrderStatus.FILLABLE) {
            revert("order status is not FILLABLE");
        }

        // get takerTokenFillAmount
        uint256 takerTokenFillAmount = getTakerTokenFillAmount(adapterBalance, order.takerTokenFeeAmount, order.takerAmount);

        // exchange with ZeroEx
        // No need to use the return vaule from fillLimitOrder (uint128 takerTokenFilledAmount, uint128 makerTokenFilledAmount)
        // because we use the fromToken.balanceOf(this) as return vaule
        IZeroEx(EXCHANGE_PROXY).fillLimitOrder(
            order,
            makerSignature,
            uint128(takerTokenFillAmount)
        );

        // approve 0
        SafeERC20.safeApprove(
            IERC20(fromToken == ETH_ADDRESS ? WETH_ADDRESS : fromToken),
            EXCHANGE_PROXY,
            0
        );

        if (toToken == ETH_ADDRESS) {
            IWETH(WETH_ADDRESS).deposit{value: address(this).balance}();
            toToken = WETH_ADDRESS;
        }

        if (to != address(this)) {
            SafeERC20.safeTransfer(
                IERC20(toToken),
                to,
                IERC20(toToken).balanceOf(address(this))
            );
        }
    }

    // ========================================================
    // rate = takerTokenFeeAmount / takerAmount
    // (1) takerTokenFillAmount * rate = Fee
    // (2) takerTokenFillAmount + Fee = adapterBalance
    // merge formular (1) and (2) =>
    // (3) takerTokenFillAmount = adapterBalance / (1 + rate) 
    //                          = adapterBalance / (1 + takerTokenFeeAmount / takerAmount)
    //                          = adapterBalance / ( (takerAmount + takerTokenFeeAmount) /  takerAmount)
    //                          = adapterBalance * takerAmount / (takerAmount + takerTokenFeeAmount)
    // ========================================================

    function getTakerTokenFillAmount(
        uint256 adapterBalance,
        uint256 takerTokenFeeAmount,
        uint256 takerAmount
    ) internal pure returns (uint256 takerTokenFillAmount) {
        takerTokenFillAmount = adapterBalance.mul(takerAmount).div(takerAmount + takerTokenFeeAmount);
    }

    function withdrawTokenLeft(address toToken) public onlyAdmin {
        if (toToken != address(this)) {
            if (toToken == ETH_ADDRESS) {
                IWETH(WETH_ADDRESS).deposit{value: address(this).balance}();
                toToken = WETH_ADDRESS;
            }
            SafeERC20.safeTransfer(
                IERC20(toToken),
                msg.sender,
                IERC20(toToken).balanceOf(address(this))
            );
        }
    }

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _rfqSwap(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _rfqSwap(to, pool, moreInfo);
    }

    

    event Received(address, uint256);

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}