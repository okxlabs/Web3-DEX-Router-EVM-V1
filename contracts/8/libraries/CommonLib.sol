/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CommonUtils.sol";
import "./SafeERC20.sol";
import "./UniversalERC20.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IApproveProxy.sol";
import "../interfaces/IWNativeRelayer.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IERC20.sol";


/// @title Base contract with common permit handling logics
abstract contract CommonLib is CommonUtils {
    using UniversalERC20 for IERC20;

    function _exeAdapter(
        bool reverse,
        address adapter,
        address to,
        address poolAddress,
        bytes memory moreinfo,
        address refundTo
    ) internal {
        if (reverse) {
            (bool s, bytes memory res) = address(adapter).call(
                abi.encodePacked(
                    abi.encodeWithSelector(
                        IAdapter.sellQuote.selector,
                        to,
                        poolAddress,
                        moreinfo
                    ),
                    ORIGIN_PAYER + uint(uint160(refundTo))
                )
            );
            if (!s) {
                _revert(res);
            }
        } else {
            (bool s, bytes memory res) = address(adapter).call(
                abi.encodePacked(
                    abi.encodeWithSelector(
                        IAdapter.sellBase.selector,
                        to,
                        poolAddress,
                        moreinfo
                    ),
                    ORIGIN_PAYER + uint(uint160(refundTo))
                )
            );
            if (!s) {
                _revert(res);
            }
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with "FailedCall".
     * https://github.com/OpenZeppelin/openzeppelin-contracts/blob/c64a1edb67b6e3f4a15cca8909c9482ad33a02b0/contracts/utils/Address.sol#L135-L149
     */
    function _revert(bytes memory returndata) internal pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                revert(add(returndata, 0x20), mload(returndata))
            }
        } else {
            revert("adaptor call failed");
        }
    }

    /// @notice Transfers tokens internally within the contract.
    /// @param payer The address of the payer.
    /// @param to The address of the receiver.
    /// @param fromTokenWithMode FromToken with mode encoded in high bits
    /// @param amount The amount of tokens to be transferred.
    /// @dev Handles the transfer of ERC20 tokens or native tokens within the contract.
    function _transferInternal(
        address payer,
        address to,
        uint256 fromTokenWithMode,
        uint256 amount
    ) internal {
        address token = address(uint160(fromTokenWithMode & _ADDRESS_MASK));
        uint256 mode = fromTokenWithMode & _TRANSFER_MODE_MASK;
        
        if (mode == _MODE_NO_TRANSFER) {
            return;
        } else if (mode == _MODE_BY_INVEST) {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
            return;
        } else if (mode == _MODE_PERMIT2) {
            // Permit2 mode - reserved for future implementation
            return;
        } else {
            if (payer == address(this)) {
                SafeERC20.safeTransfer(IERC20(token), to, amount);
            } else {
                IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, to, amount);
            }
        }
    }

    /// @notice Transfers the specified token to the user.
    /// @param token The address of the token to be transferred.
    /// @param to The address of the receiver.
    /// @dev Handles the withdrawal of tokens to the user, converting WETH to ETH if necessary.
    function _transferTokenToUser(address token, address to) internal {
        if ((IERC20(token).isETH())) {
            uint256 wethBal = IERC20(address(uint160(_WETH))).balanceOf(
                address(this)
            );
            if (wethBal > 0) {
                IWETH(address(uint160(_WETH))).transfer(
                    _WNATIVE_RELAY,
                    wethBal
                );
                IWNativeRelayer(_WNATIVE_RELAY).withdraw(wethBal);
            }
            if (to != address(this)) {
                uint256 ethBal = address(this).balance;
                if (ethBal > 0) {
                    (bool success, ) = payable(to).call{value: ethBal}("");
                    require(success, "transfer native token failed");
                }
            }
        } else {
            if (to != address(this)) {
                uint256 bal = IERC20(token).balanceOf(address(this));
                if (bal > 0) {
                    SafeERC20.safeTransfer(IERC20(token), to, bal);
                }
            }
        }
    }

    /// @notice Converts a uint256 value into an address.
    /// @param param The uint256 value to be converted.
    /// @return result The address obtained from the conversion.
    /// @dev This function is used to extract an address from a uint256,
    /// typically used when dealing with low-level data operations or when addresses are packed into larger data types.
    function _bytes32ToAddress(
        uint256 param
    ) internal pure returns (address result) {
        assembly {
            result := and(param, _ADDRESS_MASK)
        }
    }
}
