// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "contracts/8/storage/DexRouterStorage.sol";
contract SigVerify is DexRouterStorage {
    uint256 internal constant _SIG_FLAG_MASK =
        0xffffffffffff0000000000000000000000000000000000000000000000000000;
    uint256 internal constant _DEADLINE_MASK =
        0x000000000000ffffffffffff0000000000000000000000000000000000000000;
    uint256 internal constant _V_FLAG_MASK =
        0x00000000000000000000000000000000000000000000000000000000000000ff;
    uint256 internal constant _SIG_FLAG =
        0xaaaaaaaaaaaa0000000000000000000000000000000000000000000000000000;
    uint internal constant _FLAG_OFFSET = 32 * 3;
    uint internal constant _SIG_OFFSET = 32 * 2 + 1;
    uint internal constant _SIG_SIZE = 32 * 2 + 1;
    uint internal constant _SIG_PLUS_MSG_SIZE = 32 * 2 + 1 + 32 + 31; //r + s + v + msg + empty
    bytes32 internal constant _DEXROUTER_FLAG = keccak256("dex router");

    // Data structure:
    //   - swap_data()
    //   - memo (64 bytes)
    //   - commissionInfo (64 bytes or 96 bytes)
    //   - sig (32 bytes + 64 bytes)
    // Signature format:
    //   - FLAG //6
    //   - DEADLINE //6
    //   - EMPTY //19
    //   - V //1
    //   - R //32
    //   - S //32
    // The signature includes a deadline parameter.
    // Message composition: <caller, deadline, chainid> => <caller, DexRouterFlag, deadline, chainid>
    // Implementation note:
    //   - No need to store records in the contract,
    //     simply compare deadline with block.timestamp.
    // Advantage:
    //   - Reduces gas consumption.
    // Disadvantage:
    //   - Susceptible to replay attacks within the deadline timeframe.
    function _verify_sig() internal view {
        // extract flag
        address signer;
        bytes32 dexRouterFlag = _DEXROUTER_FLAG;
        assembly ("memory-safe") {
            function _revertWithReason(m, len) {
                mstore(
                    0,
                    0x08c379a000000000000000000000000000000000000000000000000000000000
                )
                mstore(
                    0x20,
                    0x0000002000000000000000000000000000000000000000000000000000000000
                )
                mstore(0x40, m)
                revert(0, len)
            }
            function _safe_sub(a, b) -> c {
                if lt(a, b) {
                    _revertWithReason(
                        0x000000147375627472616374696f6e206f766572666c6f770000000000000000,
                        0x58
                    )
                }
                c := sub(a, b)
            }
            let firstWord := calldataload(
                _safe_sub(calldatasize(), _FLAG_OFFSET)
            )
            let flag := and(firstWord, _SIG_FLAG_MASK)
            if eq(flag, _SIG_FLAG) {
                let deadline := shr(160, and(firstWord, _DEADLINE_MASK))
                // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/10a776bae653a3d388e75954d44bd34d746e2dda/contracts/utils/cryptography/ECDSA.sol#L143
                if gt(
                    calldataload(sub(calldatasize(), 0x20)),
                    0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
                ) {
                    _revertWithReason(
                        0x00000011496e76616c69645369676e6174757265530000000000000000000000,
                        0x55
                    )
                }
                if gt(deadline, timestamp()) {
                    let freePtr := mload(0x40)
                    mstore(0x40, add(freePtr, 0x80))

                    // struct hash
                    mstore(freePtr, caller())
                    mstore(add(freePtr, 0x20), dexRouterFlag)
                    mstore(add(freePtr, 0x40), deadline)
                    mstore(add(freePtr, 0x60), chainid())
                    let message := keccak256(freePtr, 0x80)

                    // personal-sign
                    mstore(freePtr, "\x19Ethereum Signed Message:\n32")
                    mstore(add(freePtr, 0x1c), message)
                    message := keccak256(freePtr, 0x3c)
                    // ecrecover: staticcall 0x01
                    mstore(freePtr, message)
                    mstore(add(freePtr, 0x20), and(firstWord, _V_FLAG_MASK)) //copy v
                    calldatacopy(
                        add(freePtr, 0x40),
                        sub(calldatasize(), 0x40),
                        0x40
                    ) //copy r,s
                    pop(
                        staticcall(
                            gas(),
                            0x01,
                            freePtr,
                            _SIG_PLUS_MSG_SIZE,
                            0,
                            0x20
                        )
                    )
                    // returndatacopy(0, 0, 0x20)
                    signer := mload(0)
                }
            }
        }

        require(
            signer != address(0) && validSigner[signer],
            "Invalid signature"
        );
    }
}
