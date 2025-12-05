// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IAdapter.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IFluidDexV2Router.sol";
import "../libraries/SafeERC20.sol";

contract FluidDexV2D3D4Adapter is IAdapter {
    /// @dev specific flag for refund logic, "0x3ca20afc" is flexible and also used for commission, "ccc" mean refund
    uint256 constant ORIGIN_PAYER = 0x3ca20afc2ccc0000000000000000000000000000000000000000000000000000;
    uint256 constant ADDRESS_MASK = 0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff;

    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public immutable WETH;
    address public immutable FLUID_DEX_V2_ROUTER;

    event Received(address, uint256);

    constructor(address weth, address fluidDexV2Router) {
        WETH = weth;
        FLUID_DEX_V2_ROUTER = fluidDexV2Router;
    }

    function sellBase(
        address to,
        address, // pool is always FLUID_DEX_V2
        bytes memory moreInfo
    ) external override {
        _swap(to, moreInfo);
    }

    function sellQuote(
        address to,
        address, // pool is always FLUID_DEX_V2
        bytes memory moreInfo
    ) external override {
        _swap(to, moreInfo);
    }

    function _swap(
        address to,
        bytes memory moreInfo
    ) internal {
        // path_ is the array of token addresses defining the swap route. Length must be swapInConfigs_.length + 1.
        // The ETH address is 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE in the path_ array and dexKey in swapInConfigs array.
        (address[] memory path_, IFluidDexV2Router.SwapInConfig[] memory swapInConfigs_) = abi.decode(moreInfo, (address[], IFluidDexV2Router.SwapInConfig[]));

        address fromToken = path_[0];
        address toToken = path_[path_.length - 1];
        address receiver = toToken == ETH ? address(this) : to; // If the toToken is ETH, the ETH needs to be wrapped to WETH and sent to the to address

        // Execute swap
        if (fromToken == ETH) {
            uint256 amountIn = IWETH(WETH).balanceOf(address(this));
            IWETH(WETH).withdraw(amountIn);
            IFluidDexV2Router(FLUID_DEX_V2_ROUTER).swapInMulti{value: amountIn}(path_, swapInConfigs_, amountIn, receiver);
        } else {
            uint256 amountIn = IERC20(fromToken).balanceOf(address(this));
            SafeERC20.safeApprove(IERC20(fromToken), FLUID_DEX_V2_ROUTER, amountIn);
            IFluidDexV2Router(FLUID_DEX_V2_ROUTER).swapInMulti(path_, swapInConfigs_, amountIn, receiver);
        }

        if (toToken == ETH) {
            uint256 amountOut = address(this).balance;
            IWETH(WETH).deposit{value: amountOut}();
            IWETH(WETH).transfer(to, amountOut);
        }

        // Refund logic: if there is leftover fromToken, refund to payerOrigin
        address payerOrigin = _getPayerOrigin();
        if (fromToken == ETH) {
            uint256 amount = address(this).balance;
            if (amount > 0 && payerOrigin != address(0)) {
                (bool success, ) = payerOrigin.call{value: amount}("");
                require(success, "ETH transfer failed");
            }
        } else {
            uint256 amount = IERC20(fromToken).balanceOf(address(this));
            if (amount > 0 && payerOrigin != address(0)) {
                SafeERC20.safeTransfer(IERC20(fromToken), payerOrigin, amount);
            }
        }
    }

    function _getPayerOrigin() internal pure returns (address payerOrigin) {
        uint256 _payerOrigin;
        assembly {
            // Get the total size of the calldata
            let size := calldatasize()
            // Load the last 32 bytes of the calldata, which is assumed to contain the payer origin
            // Assumption: The calldata is structured such that the payer origin is always at the end
            _payerOrigin := calldataload(sub(size, 32))
        }
        if ((_payerOrigin & ORIGIN_PAYER) == ORIGIN_PAYER) {
            payerOrigin = address(uint160(uint256(_payerOrigin) & ADDRESS_MASK));
        } else {
            revert("Invalid payer origin");
        }
    }

    receive() external payable {
        require(msg.value > 0, "receive error");
        emit Received(msg.sender, msg.value);
    }
}