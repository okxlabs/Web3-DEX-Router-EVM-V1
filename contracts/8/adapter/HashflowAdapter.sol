// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/IAdapter.sol";
import "../interfaces/IHashflow.sol";
import "../interfaces/IERC20.sol";
import "../libraries/SafeERC20.sol";
import "../interfaces/IWETH.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";


contract HashflowAdapter is IAdapter, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    address public HASHFLOWROUTER ;
    address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public  WETH_ADDRESS;
    
    function initialize(
        address _HashflowRouter,
        address _weth
    ) public initializer {
        __Ownable_init();
        HASHFLOWROUTER = _HashflowRouter;
        WETH_ADDRESS = _weth;
    }

    function _hashflowSwap(
        address to,
        address pool,
        bytes memory moreInfo
    ) internal {        
        ( address fromToken, address toToken, IQuote memory Quote) = abi.decode(moreInfo, (address, address, IQuote));
        require( Quote.pool == pool, "error pool" );
        
        if (fromToken == ETH_ADDRESS) {
            Quote.effectiveBaseTokenAmount = IWETH(WETH_ADDRESS).balanceOf(address(this));
            IWETH(WETH_ADDRESS).withdraw(Quote.effectiveBaseTokenAmount);
            IHashflow(HASHFLOWROUTER).tradeSingleHop{value: Quote.effectiveBaseTokenAmount}(Quote);
        } else {
            Quote.effectiveBaseTokenAmount = IERC20(fromToken).balanceOf(address(this));
            SafeERC20.safeApprove(IERC20(fromToken), HASHFLOWROUTER,  Quote.effectiveBaseTokenAmount );
            IHashflow(HASHFLOWROUTER).tradeSingleHop(Quote);
        }

        // approve 0
        SafeERC20.safeApprove(
            IERC20(fromToken == ETH_ADDRESS ? WETH_ADDRESS : fromToken),
            pool,
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