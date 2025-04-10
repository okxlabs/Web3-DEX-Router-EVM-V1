// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/test.sol";
import {console2} from "forge-std/console2.sol";
import "@dex/DexRouter.sol";
import {IERC20} from "@dex/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract VerifySigTest is Test {
    uint256 public pk = 1;
    address public signer = vm.rememberKey(pk);
    address internal constant _ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public dexRouter = 0x3b3ae790Df4F312e745D270119c6052904FB6790;
    address admin = 0xAcE2B3E7c752d5deBca72210141d464371b3B9b1;
    bytes32 internal constant _DEXROUTER_FLAG = keccak256("dex router");
    bytes32 public STRUCT_HASH;
    bytes32 public DOMAIN_SEPARATOR;
    uint256 internal constant DENOMINATOR = 10 ** 10;

    function _getStructHash() internal view returns (bytes32) {
        return keccak256("SignInfo(address sender,uint256 deadline)");
    }

    function _getDomainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256("okx dex router"),
                    keccak256("v1.1"),
                    block.chainid,
                    dexRouter
                )
            );
    }

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com");
        vm.etch(dexRouter, address(new DexRouter()).code);
        STRUCT_HASH = _getStructHash();
        DOMAIN_SEPARATOR = _getDomainSeparator();
        vm.prank(admin);
        dexRouter.call(
            abi.encodeWithSignature(
                "setValidSigner(address,bool)",
                signer,
                true
            )
        );
    }

    function _construct_swap_data() internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(WrapETHSwap.swapWrap.selector, 1, 1 ether);
    }

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function _construct_commission_data_to_token(
        bool onlyOne
    ) internal returns (bytes memory) {
        if (onlyOne) {
            bytes32 firstWord = bytes32(
                abi.encodePacked(
                    uint48(0x3ca20afc2bbb),
                    uint48(100000000),
                    makeAddr("1")
                )
            );
            bytes32 secondWord = bytes32(uint256(uint160(WETH)));
            return abi.encode(secondWord, firstWord);
        } else {
            bytes32 firstWord = bytes32(
                abi.encodePacked(
                    uint48(0x22220afc2bbb),
                    uint48(100000000),
                    makeAddr("1")
                )
            );
            bytes32 secondWord = bytes32(uint256(uint160(WETH)));
            bytes32 thirdWord = bytes32(
                abi.encodePacked(
                    uint48(0x22220afc2bbb),
                    uint48(100000000),
                    makeAddr("2")
                )
            );
            return abi.encode(thirdWord, secondWord, firstWord);
        }
    }

    function _construct_commission_data_from_token(
        bool onlyOne
    ) internal returns (bytes memory) {
        if (onlyOne) {
            bytes32 firstWord = bytes32(
                abi.encodePacked(
                    uint48(0x3ca20afc2aaa),
                    uint48(100000000),
                    makeAddr("1")
                )
            );
            bytes32 secondWord = bytes32(uint256(uint160(_ETH)));
            return abi.encode(secondWord, firstWord);
        } else {
            bytes32 firstWord = bytes32(
                abi.encodePacked(
                    uint48(0x22220afc2aaa),
                    uint48(100000000),
                    makeAddr("1")
                )
            );
            bytes32 secondWord = bytes32(uint256(uint160(_ETH)));
            bytes32 thirdWord = bytes32(
                abi.encodePacked(
                    uint48(0x22220afc2aaa),
                    uint48(100000000),
                    makeAddr("2")
                )
            );
            return abi.encode(thirdWord, secondWord, firstWord);
        }
    }

    function _sign(
        address user,
        uint48 deadline
    ) internal returns (uint8, bytes32, bytes32, bytes32) {
        bytes32 structHash = keccak256(
            abi.encode(user, _DEXROUTER_FLAG, deadline, block.chainid)
        );
        console2.log("signer", vm.rememberKey(pk));
        bytes32 message = ECDSA.toEthSignedMessageHash(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, message);
        return (v, r, s, message);
    }

    function _encodeSig(
        uint8 v,
        bytes32 r,
        bytes32 s,
        uint48 deadline
    ) internal pure returns (bytes memory) {
        bytes32 firstWord = bytes32(
            abi.encodePacked(
                uint48(0xaaaaaaaaaaaa),
                uint48(deadline),
                uint152(0),
                uint8(v)
            )
        );
        bytes32 secondWord = r;
        bytes32 thirdWord = s;
        return abi.encode(firstWord, secondWord, thirdWord);
    }

    function test_simple_verify() public {
        uint48 deadline = type(uint48).max;
        address user = address(this);
        console2.log("user", user);
        (uint8 v, bytes32 r, bytes32 s, bytes32 message) = _sign(
            user,
            deadline
        );

        bytes memory signature = _encodeSig(v, r, s, deadline);
        bytes memory data = bytes.concat(_construct_swap_data(), signature);
        // bytes memory data = bytes.concat(_construct_swap_data(), "");
        console2.log("domain");
        console2.logBytes32(_getDomainSeparator());
        uint gas = gasleft();
        (bool success, ) = payable(dexRouter).call{value: 1 ether}(data);
        console2.log("gas", gas - gasleft());
    }

    function test_verify_with_commission_to_token() public {
        uint48 deadline = type(uint48).max;
        address user = address(this);
        console2.log("user", user);
        (uint8 v, bytes32 r, bytes32 s, bytes32 message) = _sign(
            user,
            deadline
        );

        bytes memory signature = _encodeSig(v, r, s, deadline);
        bytes memory data = bytes.concat(
            _construct_swap_data(),
            _construct_commission_data_to_token(false),
            signature
        );
        (bool success, ) = payable(dexRouter).call{value: 1 ether}(data);
        console2.logBytes(data);
    }

    function test_verify_with_commission_from_token() public {
        uint48 deadline = type(uint48).max;
        address user = address(this);
        console2.log("user", user);
        (uint8 v, bytes32 r, bytes32 s, bytes32 message) = _sign(
            user,
            deadline
        );

        bytes memory signature = _encodeSig(v, r, s, deadline);
        bytes memory data = bytes.concat(
            _construct_swap_data(),
            _construct_commission_data_from_token(false),
            signature
        );
        (bool success, ) = payable(dexRouter).call{value: 1.2 ether}(data);
        console2.logBytes(data);
    }
    /**
     * @notice Test signature verification during a swap via investment path
     * @dev Tests the signature verification mechanism with the investment data flow
     */

    function test_verify_by_invest() public {
        // Set maximum deadline for the signature
        uint48 deadline = type(uint48).max;
        address user = address(this);

        console2.log("User address:", user);

        // Generate signature components for the current user and deadline
        (uint8 v, bytes32 r, bytes32 s, bytes32 message) = _sign(
            user,
            deadline
        );

        // Encode the signature with proper format
        bytes memory signature = _encodeSig(v, r, s, deadline);

        // Combine investment swap data with the signature
        bytes memory callData = bytes.concat(
            _construct_swap_by_invest_data(),
            signature
        );

        // Execute the call to the router with 1 ETH
        (bool success, ) = payable(dexRouter).call{value: 1 ether}(callData);
        require(success, "Investment swap call failed");

        // Log signature for debugging
        console2.log("Signature length:", signature.length);
        console2.logBytes(signature);
    }

    /**
     * @notice Struct defining swap information for investment flow
     * @dev Contains all necessary parameters for a structured investment swap
     */
    struct SwapInfo {
        uint256 orderId;
        DexRouter.BaseRequest baseRequest;
        uint256[] batchesAmount;
        DexRouter.RouterPath[][] batches;
        PMMLib.PMMSwapRequest[] extraData;
    }

    /**
     * @notice Constructs swap data for the investment path
     * @dev Creates a structured payload for an investment swap operation
     * @return bytes Memory containing the encoded swap data
     */
    function _construct_swap_by_invest_data()
        internal
        view
        returns (bytes memory)
    {
        // Define constants and setup
        uint256 amount = 1000000;
        address adapter = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45; // Example adapter address
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address USDA = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
        address USDA_USDC = 0x7e3239b0c71c3f9Fe8e7B071834b0ccFb7168184; // LP pair or pool

        // Initialize the swap info structure
        SwapInfo memory swapInfo;

        // Configure base request parameters
        swapInfo.baseRequest.fromToken = uint256(uint160(address(_ETH)));
        swapInfo.baseRequest.toToken = WETH;
        swapInfo.baseRequest.fromTokenAmount = amount;
        swapInfo.baseRequest.minReturnAmount = 0;
        swapInfo.baseRequest.deadLine = block.timestamp;

        // Configure batches information
        swapInfo.batchesAmount = new uint256[](1);
        swapInfo.batchesAmount[0] = amount;

        // Setup router paths
        swapInfo.batches = new DexRouter.RouterPath[][](1);
        swapInfo.batches[0] = new DexRouter.RouterPath[](1);

        // Configure adapter settings
        swapInfo.batches[0][0].mixAdapters = new address[](1);
        swapInfo.batches[0][0].mixAdapters[0] = address(adapter);

        // Configure asset destinations
        swapInfo.batches[0][0].assetTo = new address[](1);
        swapInfo.batches[0][0].assetTo[0] = address(adapter); // Direct interaction with adapter

        // Configure raw data
        swapInfo.batches[0][0].rawData = new uint256[](1);
        swapInfo.batches[0][0].rawData[0] = uint256(
            bytes32(abi.encodePacked(false, uint88(10000), address(USDA_USDC)))
        );

        // Set extra data for the path
        swapInfo.batches[0][0].extraData = new bytes[](1);
        swapInfo.batches[0][0].extraData[0] = abi.encode(USDC, USDA);

        // Set the from token for this specific path
        swapInfo.batches[0][0].fromToken = uint256(uint160(address(USDC)));

        // Initialize empty PMMSwapRequest array
        swapInfo.extraData = new PMMLib.PMMSwapRequest[](0);

        // Return the encoded swap information
        return
            abi.encodeWithSelector(
                DexRouter.smartSwapByInvest.selector,
                swapInfo.baseRequest,
                swapInfo.batchesAmount,
                swapInfo.batches,
                swapInfo.extraData,
                address(this),
                address(this)
            );
    }
}
