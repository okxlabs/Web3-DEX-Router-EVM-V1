// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./UnxswapRouter.sol";
import "./UnxswapV3Router.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/IAdapter.sol";
import "./interfaces/IApproveProxy.sol";
import "./interfaces/IWNativeRelayer.sol";
import "./interfaces/IXBridge.sol";
import "./interfaces/IUniV3.sol";

import "./libraries/Permitable.sol";
import "./libraries/PMMLib.sol";
import "./libraries/CommissionLib.sol";
import "./libraries/EthReceiver.sol";
import "./libraries/WrapETHSwap.sol";
import "./libraries/CommonUtils.sol";
import "./storage/PMMRouterStorage.sol";

import "./storage/DexRouterStorage.sol";

/// @title DexRouterV1
/// @notice Entrance of Split trading in Dex platform
/// @dev Entrance of Split trading in Dex platform
contract DexRouter is
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    Permitable,
    EthReceiver,
    UnxswapRouter,
    UnxswapV3Router,
    DexRouterStorage,
    WrapETHSwap,
    CommissionLib,
    PMMRouterStorage
{
    using UniversalERC20 for IERC20;

    struct BaseRequest {
        uint256 fromToken;
        address toToken;
        uint256 fromTokenAmount;
        uint256 minReturnAmount;
        uint256 deadLine;
    }

    struct RouterPath {
        address[] mixAdapters;
        address[] assetTo;
        uint256[] rawData;
        bytes[] extraData;
        uint256 fromToken;
    }
    /// @notice Initializes the contract with necessary setup for ownership and reentrancy protection.
    /// @dev This function serves as a constructor for upgradeable contracts and should be called
    /// through a proxy during the initial deployment. It initializes inherited contracts
    /// such as `OwnableUpgradeable` and `ReentrancyGuardUpgradeable` to set up the contract's owner
    /// and reentrancy guard.

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
    }

    //-------------------------------
    //------- Events ----------------
    //-------------------------------

    /// @notice Emitted when a priority address status is updated.
    /// @param priorityAddress The address whose priority status has been changed.
    /// @param valid A boolean indicating the new status of the priority address.
    /// True means the address is now considered a priority address, and false means it is not.
    event PriorityAddressChanged(address priorityAddress, bool valid);

    /// @notice Emitted when the admin address of the contract is changed.
    /// @param newAdmin The address of the new admin.
    event AdminChanged(address newAdmin);

    event ValidSignerChanged(address signer, bool valid);

    //-------------------------------
    //------- Modifier --------------
    //-------------------------------
    /// @notice Ensures a function is called before a specified deadline.
    /// @param deadLine The UNIX timestamp deadline.
    modifier isExpired(uint256 deadLine) {
        require(deadLine >= block.timestamp, "Route: expired");
        _;
    }
    /// @notice Restricts function access to addresses marked as priority.
    /// Ensures that only addresses designated with specific privileges can execute the function.

    modifier onlyPriorityAddress() {
        require(priorityAddresses[msg.sender] == true, "only priority");
        _;
    }
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
            require(s, string(res));
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
            require(s, string(res));
        }
    }
    //-------------------------------
    //------- Internal Functions ----
    //-------------------------------
    /// @notice Executes multiple adapters for a transaction pair.
    /// @param payer The address of the payer.
    /// @param to The address of the receiver.
    /// @param batchAmount The amount to be transferred in each batch.
    /// @param path The routing path for the swap.
    /// @param noTransfer A flag to indicate whether the token transfer should be skipped.
    /// @dev It includes checks for the total weight of the paths and executes the swapping through the adapters.
    function _exeForks(
        address payer,
        address refundTo,
        address to,
        uint256 batchAmount,
        RouterPath memory path,
        bool noTransfer
    ) private {
        uint256 totalWeight;
        for (uint256 i = 0; i < path.mixAdapters.length; i++) {
            bytes32 rawData = bytes32(path.rawData[i]);
            address poolAddress;
            bool reverse;
            {
                uint256 weight;
                address fromToken = _bytes32ToAddress(path.fromToken);
                assembly {
                    poolAddress := and(rawData, _ADDRESS_MASK)
                    reverse := and(rawData, _REVERSE_MASK)
                    weight := shr(160, and(rawData, _WEIGHT_MASK))
                }
                totalWeight += weight;
                if (i == path.mixAdapters.length - 1) {
                    require(
                        totalWeight <= 10_000,
                        "totalWeight can not exceed 10000 limit"
                    );
                }

                if (!noTransfer) {
                    uint256 _fromTokenAmount = weight == 10_000
                        ? batchAmount
                        : (batchAmount * weight) / 10_000;
                    _transferInternal(
                        payer,
                        path.assetTo[i],
                        fromToken,
                        _fromTokenAmount
                    );
                }
            }

            _exeAdapter(
                reverse,
                path.mixAdapters[i],
                to,
                poolAddress,
                path.extraData[i],
                refundTo
            );
        }
    }
    /// @notice Executes a series of swaps or operations defined by a set of routing paths, potentially across different protocols or pools.
    /// @param payer The address providing the tokens for the swap.
    /// @param receiver The address receiving the output tokens.
    /// @param isToNative Indicates whether the final asset should be converted to the native blockchain asset (e.g., ETH).
    /// @param batchAmount The total amount of the input token to be swapped.
    /// @param hops An array of RouterPath structures, each defining a segment of the swap route.
    /// @dev This function manages complex swap routes that might involve multiple hops through different liquidity pools or swapping protocols.
    /// It iterates through the provided `hops`, executing each segment of the route in sequence.

    function _exeHop(
        address payer,
        address refundTo,
        address receiver,
        bool isToNative,
        uint256 batchAmount,
        RouterPath[] memory hops
    ) private {
        address fromToken = _bytes32ToAddress(hops[0].fromToken);
        bool toNext;
        bool noTransfer;

        // execute hop
        uint256 hopLength = hops.length;
        for (uint256 i = 0; i < hopLength; ) {
            if (i > 0) {
                fromToken = _bytes32ToAddress(hops[i].fromToken);
                batchAmount = IERC20(fromToken).universalBalanceOf(
                    address(this)
                );
                payer = address(this);
            }

            address to = address(this);
            if (i == hopLength - 1 && !isToNative) {
                to = receiver;
            } else if (i < hopLength - 1 && hops[i + 1].assetTo.length == 1) {
                to = hops[i + 1].assetTo[0];
                toNext = true;
            } else {
                toNext = false;
            }

            // 3.2 execute forks
            _exeForks(payer, refundTo, to, batchAmount, hops[i], noTransfer);
            noTransfer = toNext;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Transfers tokens internally within the contract.
    /// @param payer The address of the payer.
    /// @param to The address of the receiver.
    /// @param token The address of the token to be transferred.
    /// @param amount The amount of tokens to be transferred.
    /// @dev Handles the transfer of ERC20 tokens or native tokens within the contract.
    function _transferInternal(
        address payer,
        address to,
        address token,
        uint256 amount
    ) private {
        if (payer == address(this)) {
            SafeERC20.safeTransfer(IERC20(token), to, amount);
        } else {
            IApproveProxy(_APPROVE_PROXY).claimTokens(token, payer, to, amount);
        }
    }
    /// @notice Transfers the specified token to the user.
    /// @param token The address of the token to be transferred.
    /// @param to The address of the receiver.
    /// @dev Handles the withdrawal of tokens to the user, converting WETH to ETH if necessary.

    function _transferTokenToUser(address token, address to) private {
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
    ) private pure returns (address result) {
        assembly {
            result := and(param, _ADDRESS_MASK)
        }
    }
    /// @notice Executes a complex swap based on provided parameters and paths.
    /// @param baseRequest Basic swap details including tokens, amounts, and deadline.
    /// @param batchesAmount Amounts for each swap batch.
    /// @param batches Detailed swap paths for execution.
    /// @param payer Address providing the tokens.
    /// @param receiver Address receiving the swapped tokens.
    /// @return returnAmount Total received tokens from the swap.

    function _smartSwapInternal(
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        address payer,
        address refundTo,
        address receiver
    ) private returns (uint256 returnAmount) {
        // 1. transfer from token in
        BaseRequest memory _baseRequest = baseRequest;
        require(
            _baseRequest.fromTokenAmount > 0,
            "Route: fromTokenAmount must be > 0"
        );
        address fromToken = _bytes32ToAddress(_baseRequest.fromToken);
        returnAmount = IERC20(_baseRequest.toToken).universalBalanceOf(
            receiver
        );

        // In order to deal with ETH/WETH transfer rules in a unified manner,
        // we do not need to judge according to fromToken.
        if (UniversalERC20.isETH(IERC20(fromToken))) {
            IWETH(address(uint160(_WETH))).deposit{
                value: _baseRequest.fromTokenAmount
            }();
            payer = address(this);
        }

        // 2. check total batch amount
        {
            // avoid stack too deep
            uint256 totalBatchAmount;
            for (uint256 i = 0; i < batchesAmount.length; ) {
                totalBatchAmount += batchesAmount[i];
                unchecked {
                    ++i;
                }
            }
            require(
                totalBatchAmount <= _baseRequest.fromTokenAmount,
                "Route: number of batches should be <= fromTokenAmount"
            );
        }

        // 4. execute batch
        // check length, fix DRW-02: LACK OF LENGTH CHECK ON BATATCHES
        require(batchesAmount.length == batches.length, "length mismatch");
        for (uint256 i = 0; i < batches.length; ) {
            // execute hop, if the whole swap replacing by pmm fails, the funds will return to dexRouter
            _exeHop(
                payer,
                refundTo,
                receiver,
                IERC20(_baseRequest.toToken).isETH(),
                batchesAmount[i],
                batches[i]
            );
            unchecked {
                ++i;
            }
        }

        // 5. transfer tokens to user
        _transferTokenToUser(_baseRequest.toToken, receiver);

        // 6. check minReturnAmount
        returnAmount =
            IERC20(_baseRequest.toToken).universalBalanceOf(receiver) -
            returnAmount;
        require(
            returnAmount >= _baseRequest.minReturnAmount,
            "Min return not reached"
        );

        emit OrderRecord(
            fromToken,
            _baseRequest.toToken,
            tx.origin,
            _baseRequest.fromTokenAmount,
            returnAmount
        );
        return returnAmount;
    }

    //-------------------------------
    //------- Admin functions -------
    //-------------------------------

    /// @notice Updates the priority status of an address, allowing or disallowing it from performing certain actions.
    /// @param _priorityAddress The address whose priority status is to be updated.
    /// @param valid A boolean indicating whether the address should be marked as a priority (true) or not (false).
    /// @dev This function can only be called by the contract owner or another authorized entity.
    /// It is typically used to grant or revoke special permissions to certain addresses.
    function setPriorityAddress(address _priorityAddress, bool valid) external {
        require(msg.sender == admin || msg.sender == owner(), "na");
        priorityAddresses[_priorityAddress] = valid;
        emit PriorityAddressChanged(_priorityAddress, valid);
    }
    /// @notice Assigns a new admin address for the protocol.
    /// @param _newAdmin The address to be granted admin privileges.
    /// @dev Only the current owner or existing admin can assign a new admin, ensuring secure management of protocol permissions.
    /// Changing the admin address is a critical operation that should be performed with caution.

    function setProtocolAdmin(address _newAdmin) external {
        require(msg.sender == admin || msg.sender == owner(), "na");
        admin = _newAdmin;
        emit AdminChanged(_newAdmin);
    }

    function setValidSigner(address _signer, bool valid) external {
        require(msg.sender == admin || msg.sender == owner(), "na");
        validSigner[_signer] = valid;
        emit ValidSignerChanged(_signer, valid);
    }

    //-------------------------------
    //------- Users Functions -------
    //-------------------------------

    /// @notice Executes a smart swap operation through the XBridge, identified by a specific order ID.
    /// @param orderId The unique identifier for the swap order, facilitating tracking and reference.
    /// @param baseRequest Contains essential parameters for the swap, such as source and destination tokens, amount, minimum return, and deadline.
    /// @param batchesAmount Array of amounts for each batch in the swap, allowing for split operations across different routes or pools.
    /// @param batches Detailed paths for each swap batch, including adapters and target assets.
    /// @param extraData Additional data required for executing the swap, which may include specific instructions or parameters for adapters.
    /// @return returnAmount The total amount of the destination token received from the swap.
    /// @dev This function allows for complex swap operations across different liquidity sources or protocols, initiated via the XBridge.
    /// It's designed to be called by authorized addresses, ensuring that the swap meets predefined criteria and security measures.
    function smartSwapByOrderIdByXBridge(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata extraData
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        nonReentrant
        onlyPriorityAddress
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);
        (address payer, address receiver) = IXBridge(msg.sender)
            .payerReceiver();
        require(receiver != address(0), "not address(0)");
        return
            _smartSwapTo(
                payer,
                payer,
                receiver,
                baseRequest,
                batchesAmount,
                batches
            );
    }
    /// @notice Executes a token swap using Unxswap protocol via XBridge for a specific order ID.
    /// @param srcToken The source token's address to be swapped.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum acceptable return amount of destination tokens to ensure the swap is executed within acceptable slippage.
    /// @param pools Pool identifiers used for the swap, allowing for route optimization.
    /// @return returnAmount The amount of destination tokens received from the swap.
    /// @dev This function is designed to facilitate cross-protocol swaps through the XBridge,
    /// enabling swaps that adhere to specific routing paths defined by the pools parameter.
    /// It is accessible only to priority addresses, ensuring controlled access and execution.

    function unxswapByOrderIdByXBridge(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable onlyPriorityAddress returns (uint256 returnAmount) {
        emit SwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        (address payer, address receiver) = IXBridge(msg.sender)
            .payerReceiver();
        require(receiver != address(0), "not address(0)");
        return _unxswapTo(srcToken, amount, minReturn, payer, receiver, pools);
    }
    /// @notice Executes a token swap using the Uniswap V3 protocol through the XBridge, specifically catering to priority addresses.
    /// @param receiver The address that will receive the swap funds.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum acceptable amount of tokens to be received from the swap. This parameter ensures the swap does not proceed if the return is below the specified threshold, guarding against excessive slippage.
    /// @param pools An array of pool identifiers used to define the swap route in the Uniswap V3 pools.
    /// @return returnAmount The amount of tokens received from the swap.
    /// @dev This function is exclusively accessible to priority addresses and is responsible for executing swaps on Uniswap V3 through the XBridge interface. It ensures that the swap meets the criteria set by the parameters and utilizes the _uniswapV3Swap internal function to perform the actual swap.

    function uniswapV3SwapToByXBridge(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable onlyPriorityAddress returns (uint256 returnAmount) {
        emit SwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        (address payer, address receiver_) = IXBridge(msg.sender)
            .payerReceiver();
        require(receiver_ != address(0), "not address(0)");
        return
            _uniswapV3SwapTo(
                payer,
                uint160(receiver_),
                amount,
                minReturn,
                pools
            );
    }
    /// @notice Executes a smart swap based on the given order ID, supporting complex multi-path swaps.
    /// @param orderId The unique identifier for the swap order, facilitating tracking and reference.
    /// @param baseRequest Struct containing the base parameters for the swap, including the source and destination tokens, amount, minimum return, and deadline.
    /// @param batchesAmount An array specifying the amount to be swapped in each batch, allowing for split operations.
    /// @param batches An array of RouterPath structs defining the routing paths for each batch, enabling swaps through multiple protocols or liquidity pools.
    /// @param extraData Additional data required for some swaps, accommodating special instructions or parameters necessary for executing the swap.
    /// @return returnAmount The total amount of destination tokens received from executing the swap.
    /// @dev This function orchestrates a swap operation that may involve multiple steps, routes, or protocols based on the provided parameters.
    /// It's designed to ensure flexibility and efficiency in finding the best swap paths.

    function smartSwapByOrderId(
        uint256 orderId,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata extraData
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        nonReentrant
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);
        return
            _smartSwapTo(
                msg.sender,
                msg.sender,
                msg.sender,
                baseRequest,
                batchesAmount,
                batches
            );
    }
    /// @notice Executes a token swap using the Unxswap protocol based on a specified order ID.
    /// @param srcToken The source token involved in the swap.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of tokens expected to be received to ensure the swap does not proceed under unfavorable conditions.
    /// @param pools An array of pool identifiers specifying the pools to use for the swap, allowing for optimized routing.
    /// @return returnAmount The amount of destination tokens received from the swap.
    /// @dev This function allows users to perform token swaps based on predefined orders, leveraging the Unxswap protocol's liquidity pools. It ensures that the swap meets the user's specified minimum return criteria, enhancing trade efficiency and security.

    function unxswapByOrderId(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable returns (uint256 returnAmount) {
        emit SwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        return
            _unxswapTo(
                srcToken,
                amount,
                minReturn,
                msg.sender,
                msg.sender,
                pools
            );
    }
    /// @notice Executes a swap tailored for investment purposes, adjusting swap amounts based on the contract's balance.
    /// @param baseRequest Struct containing essential swap parameters like source and destination tokens, amounts, and deadline.
    /// @param batchesAmount Array indicating how much of the source token to swap in each batch, facilitating diversified investments.
    /// @param batches Detailed routing information for executing the swap across different paths or protocols.
    /// @param extraData Additional data for swaps, supporting protocol-specific requirements.
    /// @param to The address where the swapped tokens will be sent, typically an investment contract or pool.
    /// @return returnAmount The total amount of destination tokens received, ready for investment.
    /// @dev This function is designed for scenarios where investments are made in batches or through complex paths to optimize returns. Adjustments are made based on the contract's current token balance to ensure precise allocation.

    function smartSwapByInvest(
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        PMMLib.PMMSwapRequest[] memory extraData,
        address to
    ) external payable returns (uint256 returnAmount) {
        return
            smartSwapByInvestWithRefund(
                baseRequest,
                batchesAmount,
                batches,
                extraData,
                to,
                to
            );
    }
    function smartSwapByInvestWithRefund(
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches,
        PMMLib.PMMSwapRequest[] memory extraData,
        address to,
        address refundTo
    )
        public
        payable
        isExpired(baseRequest.deadLine)
        nonReentrant
        returns (uint256 returnAmount)
    {
        address fromToken = _bytes32ToAddress(baseRequest.fromToken);
        require(fromToken != _ETH, "Invalid source token");
        require(refundTo != address(0), "refundTo is address(0)");
        require(to != address(0), "to is address(0)");
        require(baseRequest.fromTokenAmount > 0, "fromTokenAmount is 0");
        uint256 amount = IERC20(fromToken).balanceOf(address(this));
        for (uint256 i = 0; i < batchesAmount.length; ) {
            batchesAmount[i] =
                (batchesAmount[i] * amount) /
                baseRequest.fromTokenAmount;
            unchecked {
                ++i;
            }
        }
        baseRequest.fromTokenAmount = amount;
        _verify_sig();
        return
            _smartSwapInternal(
                baseRequest,
                batchesAmount,
                batches,
                address(this), // payer
                refundTo, // refundTo
                to // receiver
            );
    }

    /// @notice Executes a Uniswap V3 swap after obtaining a permit, allowing the approval of token spending and swap execution in a single transaction.
    /// @param receiver The address that will receive the funds from the swap.
    /// @param srcToken The token that will be swapped.
    /// @param amount The amount of source tokens to be swapped.
    /// @param minReturn The minimum acceptable amount of tokens to receive from the swap, guarding against slippage.
    /// @param pools An array of Uniswap V3 pool identifiers, specifying the pools to be used for the swap.
    /// @param permit A signed permit message that allows the router to spend the source tokens without requiring a separate `approve` transaction.
    /// @return returnAmount The amount of tokens received from the swap.
    /// @dev This function first utilizes the `_permit` function to approve token spending, then proceeds to execute the swap through `_uniswapV3Swap`. It's designed to streamline transactions by combining token approval and swap execution into a single operation.
    function uniswapV3SwapToWithPermit(
        uint256 receiver,
        IERC20 srcToken,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools,
        bytes calldata permit
    ) external returns (uint256 returnAmount) {
        emit SwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        _permit(address(srcToken), permit);
        return _uniswapV3SwapTo(msg.sender, receiver, amount, minReturn, pools);
    }

    /// @notice Executes a swap using the Uniswap V3 protocol.
    /// @param receiver The address that will receive the swap funds.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum acceptable amount of tokens to receive from the swap, guarding against excessive slippage.
    /// @param pools An array of pool identifiers used to define the swap route within Uniswap V3.
    /// @return returnAmount The amount of tokens received after the completion of the swap.
    /// @dev This function wraps and unwraps ETH as required, ensuring the transaction only accepts non-zero `msg.value` for ETH swaps. It invokes `_uniswapV3Swap` to execute the actual swap and handles commission post-swap.
    function uniswapV3SwapTo(
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) external payable returns (uint256 returnAmount) {
        emit SwapOrderId((receiver & _ORDER_ID_MASK) >> 160);
        return _uniswapV3SwapTo(msg.sender, receiver, amount, minReturn, pools);
    }

    function _uniswapV3SwapTo(
        address payer,
        uint256 receiver,
        uint256 amount,
        uint256 minReturn,
        uint256[] calldata pools
    ) internal returns (uint256 returnAmount) {
        CommissionInfo memory commissionInfo = _getCommissionInfo();

        // get token from pool
        address srcToken;

        if (msg.value > 0) {
            srcToken = _ETH;
        } else {
            address poolAddr = address(uint160(pools[0] & _ADDRESS_MASK));
            bool zeroForOne = (pools[0] & _ONE_FOR_ZERO_MASK) == 0;

            if (zeroForOne) {
                srcToken = IUniV3(poolAddr).token0();
            } else {
                srcToken = IUniV3(poolAddr).token1();
            }
        }

        (
            address middleReceiver,
            uint256 balanceBefore
        ) = _doCommissionFromToken(
                commissionInfo,
                srcToken,
                payer,
                address(uint160(receiver)),
                amount
            );

        uint256 swappedAmount = _uniswapV3Swap(
            payer,
            payable(middleReceiver),
            amount,
            minReturn,
            pools
        );

        uint256 commissionAmount = _doCommissionToToken(
            commissionInfo,
            address(uint160(receiver)),
            balanceBefore
        );
        return swappedAmount - commissionAmount;
    }

    /// @notice Executes a smart swap directly to a specified receiver address.
    /// @param orderId Unique identifier for the swap order, facilitating tracking.
    /// @param receiver Address to receive the output tokens from the swap.
    /// @param baseRequest Contains essential parameters for the swap such as source and destination tokens, amounts, and deadline.
    /// @param batchesAmount Array indicating amounts for each batch in the swap, allowing for split operations.
    /// @param batches Detailed routing information for executing the swap across different paths or protocols.
    /// @param extraData Additional data required for certain swaps, accommodating specific protocol needs.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function enables users to perform token swaps with complex routing directly to a specified address,
    /// optimizing for best returns and accommodating specific trading strategies.

    function smartSwapTo(
        uint256 orderId,
        address receiver,
        BaseRequest calldata baseRequest,
        uint256[] calldata batchesAmount,
        RouterPath[][] calldata batches,
        PMMLib.PMMSwapRequest[] calldata extraData
    )
        external
        payable
        isExpired(baseRequest.deadLine)
        nonReentrant
        returns (uint256 returnAmount)
    {
        emit SwapOrderId(orderId);
        return
            _smartSwapTo(
                msg.sender,
                msg.sender,
                receiver,
                baseRequest,
                batchesAmount,
                batches
            );
    }

    function _smartSwapTo(
        address payer,
        address refundTo,
        address receiver,
        BaseRequest memory baseRequest,
        uint256[] memory batchesAmount,
        RouterPath[][] memory batches
    ) internal returns (uint256) {
        require(receiver != address(0), "not addr(0)");
        CommissionInfo memory commissionInfo = _getCommissionInfo();

        (
            address middleReceiver,
            uint256 balanceBefore
        ) = _doCommissionFromToken(
                commissionInfo,
                _bytes32ToAddress(baseRequest.fromToken),
                payer,
                receiver,
                baseRequest.fromTokenAmount
            );
        address _payer = payer; // avoid stack too deep
        uint256 swappedAmount = _smartSwapInternal(
            baseRequest,
            batchesAmount,
            batches,
            _payer,
            refundTo,
            middleReceiver
        );

        uint256 commissionAmount = _doCommissionToToken(
            commissionInfo,
            receiver,
            balanceBefore
        );
        return swappedAmount - commissionAmount;
    }
    /// @notice Executes a token swap using the Unxswap protocol, sending the output directly to a specified receiver.
    /// @param srcToken The source token to be swapped.
    /// @param amount The amount of the source token to be swapped.
    /// @param minReturn The minimum amount of destination tokens expected from the swap, ensuring the trade does not proceed under unfavorable conditions.
    /// @param receiver The address where the swapped tokens will be sent.
    /// @param pools An array of pool identifiers to specify the swap route, optimizing for best rates.
    /// @return returnAmount The total amount of destination tokens received from the swap.
    /// @dev This function facilitates direct swaps using Unxswap, allowing users to specify custom swap routes and ensuring that the output is sent to a predetermined address. It is designed for scenarios where the user wants to directly receive the tokens in their wallet or another contract.

    function unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address receiver,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) external payable returns (uint256 returnAmount) {
        emit SwapOrderId((srcToken & _ORDER_ID_MASK) >> 160);
        return
            _unxswapTo(
                srcToken,
                amount,
                minReturn,
                msg.sender,
                receiver,
                pools
            );
    }

    function _unxswapTo(
        uint256 srcToken,
        uint256 amount,
        uint256 minReturn,
        address payer,
        address receiver,
        // solhint-disable-next-line no-unused-vars
        bytes32[] calldata pools
    ) internal returns (uint256 returnAmount) {
        require(receiver != address(0), "not addr(0)");
        CommissionInfo memory commissionInfo = _getCommissionInfo();

        (
            address middleReceiver,
            uint256 balanceBefore
        ) = _doCommissionFromToken(
                commissionInfo,
                _bytes32ToAddress(srcToken),
                payer,
                receiver,
                amount
            );

        uint256 swappedAmount = _unxswapInternal(
            IERC20(address(uint160(srcToken & _ADDRESS_MASK))),
            amount,
            minReturn,
            pools,
            payer,
            middleReceiver
        );

        uint256 commissionAmount = _doCommissionToToken(
            commissionInfo,
            receiver,
            balanceBefore
        );
        return swappedAmount - commissionAmount;
    }
}
