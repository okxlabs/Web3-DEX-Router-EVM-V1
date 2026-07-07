// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../common/TrimAndCommissionTestBase.t.sol";

/// @dev Minimal callback interface (matches DexRouter.uniswapV3SwapCallback).
interface IV3Callback {
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

/// @notice A contract that *pretends* to be a Uniswap V3 pool: it answers token0()/token1()/fee()
///         with the real WETH/USDT/3000 values and forges the callback `data` so that
///         payer = victim and transferMode = LEGACY. This is exactly the "forged payer" attack.
contract FakeV3Pool {
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // View functions the router staticcalls during pool-address reconstruction.
    function token0() external pure returns (address) { return WETH; }
    function token1() external pure returns (address) { return USDT; }
    function fee() external pure returns (uint24) { return 3000; }

    /// @notice Invoke the router callback with a forged payer.
    /// @dev data layout the callback reads:
    ///      word0 = flag, word1 = payer, word2 = refundTo, word3 = transferMode
    function attack(
        address router,
        address victim,
        uint256 amount,
        uint256 mode,
        bytes32 flag
    ) external {
        bytes memory data = abi.encodePacked(
            flag,
            bytes32(uint256(uint160(victim))),        // payer  = victim
            bytes32(uint256(uint160(address(this)))), // refundTo
            bytes32(mode)                             // transferMode
        );
        // amount0Delta > 0 => callback must pay token0 (= WETH) `amount` to caller() (this pool).
        IV3Callback(router).uniswapV3SwapCallback(int256(amount), int256(-1), data);
    }
}

/// @notice Regression guard for the "forged-payer V3 callback" hypothesis on the lib-refactored router.
///
/// CONCLUSION: the attack does NOT work. The V3 callback binds itself to a genuine pool via the
/// `pool == caller()` reconstruction check (BadPool revert otherwise). That binding is the sole,
/// load-bearing defense: a real pool only calls the callback when DexRouter itself initiated the
/// swap (so `payer` is always the router's own caller), and an attacker cannot place code at a
/// genuine pool's CREATE2 address to call the callback directly.
///
/// These tests pin that invariant: if a future refactor of the callback weakens or removes the
/// pool-address binding, the forged-payer pull would start succeeding and these tests would fail.
contract ForgedPayerCallbackPoc is TrimAndCommissionTestBase {
    // Custom error selector emitted by the callback's pool check: bytes4(keccak256("BadPool()"))
    bytes4 constant BAD_POOL = 0xb2c02722;

    // V3_EXACT_IN_CALLBACK_FLAG (Constants.sol)
    bytes32 constant FLAG = 0x97d5390607e40000000000000000000000000000000000000000000000000000;

    uint256 constant PULL = 5 * 10 ** 17; // 0.5 WETH

    /// @dev Arm the victim exactly like a normal DEX user: WETH balance + a standing (LEGACY)
    ///      allowance to the real TokenApprove. setUp() already whitelisted our router in the
    ///      real TokenApproveProxy, so if the callback ever proceeded, the pull WOULD succeed.
    function _armVictim() internal {
        deal(WETH, arnaud, oneEther);
        vm.prank(arnaud);
        SafeERC20.safeApprove(IERC20(WETH), address(tokenApprove), type(uint256).max);
        assertEq(IERC20(WETH).balanceOf(arnaud), oneEther, "victim should hold WETH");
    }

    /// 1) Real-world attacker: a fake pool (NOT at a valid CREATE2 address) calls the callback
    ///    with payer=victim, mode=LEGACY. Must revert with BadPool; victim funds untouched.
    function test_forgedPayer_fakePool_reverts() public {
        _armVictim();
        FakeV3Pool fake = new FakeV3Pool();

        vm.prank(bob); // attacker
        vm.expectRevert(BAD_POOL);
        fake.attack(address(dexRouter), arnaud, PULL, _MODE_LEGACY, FLAG);

        assertEq(IERC20(WETH).balanceOf(arnaud), oneEther, "victim WETH must be untouched");
    }

    /// 2) Direct EOA call to the public callback also fails the pool check.
    function test_forgedPayer_directEoaCall_reverts() public {
        _armVictim();

        bytes memory data = abi.encodePacked(
            FLAG,
            bytes32(uint256(uint160(arnaud))),
            bytes32(uint256(uint160(bob))),
            bytes32(_MODE_LEGACY)
        );

        vm.prank(bob);
        vm.expectRevert(); // staticcall to EOA yields token0/1/fee = 0 -> computed pool != caller -> BadPool
        IV3Callback(address(dexRouter)).uniswapV3SwapCallback(int256(PULL), int256(-1), data);

        assertEq(IERC20(WETH).balanceOf(arnaud), oneEther, "victim WETH must be untouched");
    }
}
