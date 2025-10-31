// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IERC20.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IFourMeme.sol";
import "../interfaces/IWETH.sol";
import "../libraries/SafeERC20.sol";

contract FourMemeAdapter is IAdapter {

    uint256 constant MINAMOUNT = 0;
    uint256 constant PLATFORM = 0;
    uint256 constant GWEI = 10 ** 9;
    address public immutable WNATIVE;
    address public immutable TOKENMANAGER2;//0x5c952063c7fc8610FFDB798152D69F0B9550762b bsc

    struct TradeInfo {
        address fundAddress;
        address tokenAddress;
        bool buyMeme;
        uint256 sellMemeAmount;
        uint256 sellCommissionRate1;
        address sellCommissionReceiver1;
        uint256 sellCommissionRate2;
        address sellCommissionReceiver2;
        uint256 minReturnAmount;
    }

    event Received(address sender, uint256 amount);
    // To record swap info for cases that the OrderRecord event is invalid.
    // direction: true for buy meme, false for sell meme
    event OrderRecord(bool direction, address fromToken, address toToken, uint256 fromAmount, uint256 toAmount);

    constructor (
        address Wnative,
        address TokenManager2
    ) {
        WNATIVE = Wnative;
        TOKENMANAGER2 = TokenManager2;
    }

    function _fourMemeTrading(
        address to,
        bytes memory moreInfo
    ) private {
        uint256 amountIn;
        uint256 amountOut;
        TradeInfo memory tradeInfo = abi.decode(moreInfo, (TradeInfo));
        require(tradeInfo.sellCommissionRate1 + tradeInfo.sellCommissionRate2 <= 300, "exceed commission rate cap");

        if (tradeInfo.buyMeme) {
            uint256 dust;
            amountOut = IERC20(tradeInfo.tokenAddress).balanceOf(to);
            if (tradeInfo.fundAddress == WNATIVE){
                amountIn = IERC20(WNATIVE).balanceOf(address(this));
                IWETH(WNATIVE).withdraw(amountIn);
                if (isXMode(tradeInfo.tokenAddress)) {
                    bytes memory args = abi.encode(uint256(0), tradeInfo.tokenAddress, to, uint256(0), uint256(0), amountIn, MINAMOUNT);
                    ITokenManager2(TOKENMANAGER2).buyToken{value: amountIn}(args, 0, bytes("0x"));
                } else {
                    ITokenManager2(TOKENMANAGER2).buyTokenAMAP{value: amountIn}(tradeInfo.tokenAddress, to, amountIn, MINAMOUNT);
                }
                dust = address(this).balance;
                if (dust > 0) {
                    (bool success, ) = _getPayerOrigin().call{value: dust}("");
                    require(success, "Transfer failed");
                }
            }else{
                amountIn = IERC20(tradeInfo.fundAddress).balanceOf(address(this));
                IERC20(tradeInfo.fundAddress).approve(TOKENMANAGER2, amountIn);
                if (isXMode(tradeInfo.tokenAddress)) {
                    bytes memory args = abi.encode(uint256(0), tradeInfo.tokenAddress, to, uint256(0), uint256(0), amountIn, MINAMOUNT);
                    ITokenManager2(TOKENMANAGER2).buyToken(args, 0, bytes("0x"));
                } else {
                    ITokenManager2(TOKENMANAGER2).buyTokenAMAP(tradeInfo.tokenAddress, to, amountIn, MINAMOUNT);
                }
                dust = IERC20(tradeInfo.fundAddress).balanceOf(address(this));
                if (dust > 0) {
                    IERC20(tradeInfo.fundAddress).transfer(_getPayerOrigin(), dust);
                }
            }
            amountOut = IERC20(tradeInfo.tokenAddress).balanceOf(to) - amountOut;
            emit OrderRecord(true, tradeInfo.fundAddress, tradeInfo.tokenAddress, amountIn - dust, amountOut);
        } else {
            amountIn = tradeInfo.sellMemeAmount;
            if (amountIn % GWEI != 0) {
                amountIn = (amountIn / GWEI) * GWEI;
                require(amountIn > 0, "processed amountIn is 0");
            }
            address fundToken = tradeInfo.fundAddress == WNATIVE ? address(0) : tradeInfo.fundAddress;
            amountOut = _getBalance(fundToken, address(tx.origin));

            ITokenManager2(TOKENMANAGER2).sellToken(PLATFORM, tradeInfo.tokenAddress, tx.origin, amountIn, MINAMOUNT, tradeInfo.sellCommissionRate1 + tradeInfo.sellCommissionRate2, address(this));
            uint256 amountTotal= _getBalance(fundToken, address(this));
            if (tradeInfo.sellCommissionReceiver1 != address(0)) {
                uint256 amount1 = amountTotal * tradeInfo.sellCommissionRate1 / (tradeInfo.sellCommissionRate1 + tradeInfo.sellCommissionRate2);
                _safeTransfer(fundToken, tradeInfo.sellCommissionReceiver1, amount1);
            }
            if (tradeInfo.sellCommissionReceiver2 != address(0)) {
                uint256 amount2 = amountTotal * tradeInfo.sellCommissionRate2 / (tradeInfo.sellCommissionRate1 + tradeInfo.sellCommissionRate2);
                _safeTransfer(fundToken, tradeInfo.sellCommissionReceiver2, amount2);
            }
            
            amountOut = _getBalance(fundToken, tx.origin) - amountOut;
            require(amountOut >= tradeInfo.minReturnAmount, "Min return not reached");
            emit OrderRecord(false, tradeInfo.tokenAddress, tradeInfo.fundAddress, amountIn, amountOut);
        }
    }

    function _getPayerOrigin() internal pure returns (address payerOriginAddr) {
        uint256 payerOrigin;
        assembly {
            let size := calldatasize()
            payerOrigin := calldataload(sub(size, 32))
            
        }
        if (payerOrigin & 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000 == 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000) {
            payerOriginAddr = address(uint160(payerOrigin & 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff));
        }
    }

    function isXMode(address token) internal view returns (bool) {
        ITokenManager2.TokenInfo memory tokenInfo = ITokenManager2(TOKENMANAGER2)._tokenInfos(token);
        return tokenInfo.template & 0x10000 > 0;
    }

    function _getBalance(address token, address user) internal view returns (uint256) {
        if (token == address(0)) {
            return address(user).balance;
        } else {
            return IERC20(token).balanceOf(user);
        }
    }

    function _safeTransfer(address token, address receiver, uint256 amount) internal {
        if (token == address(0)) {
            (bool success, ) = payable(receiver).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            SafeERC20.safeTransfer(IERC20(token), receiver, amount);
        }
    }

    function sellBase(
        address to,
        address ,
        bytes memory moreInfo
    ) external override {
        _fourMemeTrading(to,moreInfo);
    }

    function sellQuote(
        address to,
        address ,
        bytes memory moreInfo
    ) external override {
        _fourMemeTrading(to, moreInfo);
    }

    receive() external payable {
       emit Received(msg.sender, msg.value);
   }
}
