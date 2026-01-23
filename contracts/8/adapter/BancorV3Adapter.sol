// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IBancorV3Network.sol";
import "../interfaces/IBancorV3NetworkInfo.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeMath.sol";
import "../libraries/UniversalERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";

contract BancorV3Adapter is IAdapter {
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable BANCOR_V3_ADDRESS;
    address public immutable BANCOR_V3_INFO_ADDRESS;
    address public immutable WETH_ADDRESS;

    constructor(address _bancor_network, address _bancor_network_info, address _weth) {
        BANCOR_V3_ADDRESS = _bancor_network;
        BANCOR_V3_INFO_ADDRESS = _bancor_network_info;
        WETH_ADDRESS = _weth;
    }

    function _bancorv3Trade(
        address to,
        address, /*pool*/
        bytes memory moreInfo
    ) internal {
        IBancorNetworkV3 bancorNetworkV3 = IBancorNetworkV3(BANCOR_V3_ADDRESS);
        IBancorNetworkV3Info bancorNetworkV3Info = IBancorNetworkV3Info(BANCOR_V3_INFO_ADDRESS);
        (address sourceToken, address targetToken, uint256 deadline) = abi.decode(
            moreInfo,
            (address, address, uint256)
        );

        // handle eth for special
        uint256 sellAmount = 0;
        uint256 minReturn = 0;
        uint256 returnAmount = 0;
        if (sourceToken == WETH_ADDRESS) {
            sellAmount = IWETH(WETH_ADDRESS).balanceOf(address(this));
            IWETH(WETH_ADDRESS).withdraw(sellAmount);
            minReturn = bancorNetworkV3Info.tradeOutputBySourceAmount(ETH_ADDRESS,targetToken,sellAmount);
            // trade
            returnAmount = bancorNetworkV3.tradeBySourceAmount{value: sellAmount}(ETH_ADDRESS,targetToken,sellAmount,minReturn,deadline,address(this));
        } else {
            if (targetToken == WETH_ADDRESS) {
                targetToken = ETH_ADDRESS;
            }
            sellAmount = IERC20(sourceToken).balanceOf(address(this));
            // approve
            SafeERC20.safeApprove(IERC20(sourceToken), BANCOR_V3_ADDRESS, sellAmount);

            minReturn = bancorNetworkV3Info.tradeOutputBySourceAmount(sourceToken,targetToken,sellAmount);
            // trade
            returnAmount = bancorNetworkV3.tradeBySourceAmount(sourceToken,targetToken,sellAmount,minReturn,deadline,address(this));
            // approve 0
            SafeERC20.safeApprove(
                IERC20(sourceToken),
                BANCOR_V3_ADDRESS,
                0
            );
        }

        if (targetToken == ETH_ADDRESS) {
            targetToken = WETH_ADDRESS;
            IWETH(WETH_ADDRESS).deposit{value: returnAmount}();
        }

        if (to != address(this)) {
            SafeERC20.safeTransfer(
                IERC20(targetToken),
                to,
                IERC20(targetToken).balanceOf(address(this))
            );
        }
    }

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _bancorv3Trade(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _bancorv3Trade(to, pool, moreInfo);
    }

    event Received(address, uint256);

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}
