// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IAdapter.sol";
import "../interfaces/IHashflowV3.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";

contract HashflowV3Adapter is IAdapter {
    address public HASHFLOW_V3_ROUTER;
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public WETH_ADDRESS;

    constructor(address _HashflowV3Router, address _weth) {
        HASHFLOW_V3_ROUTER = _HashflowV3Router;
        WETH_ADDRESS = _weth;
    }

    function _hashflowSwap(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {
        (address fromToken, address toToken, RFQTQuote memory Quote) = abi
            .decode(moreInfo, (address, address, RFQTQuote));
        require(Quote.pool == pool, "error pool");

        Quote.effectiveBaseTokenAmount = IERC20(fromToken).balanceOf(
            address(this)
        );
        SafeERC20.safeApprove(
            IERC20(fromToken),
            HASHFLOW_V3_ROUTER,
            Quote.effectiveBaseTokenAmount
        );
        IHashflowV3(HASHFLOW_V3_ROUTER).tradeRFQT(Quote);

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

    function sellBase(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _hashflowSwap(to, pool, moreInfo);
    }

    function sellQuote(
        address to,
        address pool,
        bytes memory moreInfo
    ) external override {
        _hashflowSwap(to, pool, moreInfo);
    }

    event Received(address, uint256);

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}
