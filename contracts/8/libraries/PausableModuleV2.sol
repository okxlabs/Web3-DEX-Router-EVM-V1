// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title PausableModuleV2 - Lightweight pause control module
 * @notice Abstract contract providing pause functionality with Owner and Reporter roles
 * @dev This is a gas-optimized implementation with zero external dependencies
 *      Storage optimization: address owner and uint64 pauseUntil are packed into the same slot
 */
abstract contract PausableModuleV2 {
    // ============ Constant Variables ============

    /// @notice Zero address constant used for address validation
    address private constant ZERO_ADDRESS = address(0);

    /// @notice Value indicating contract is not paused
    /// @dev Using 1 instead of 0 for gas optimization (avoids expensive zero->non-zero SSTORE)
    uint64 private constant NOT_PAUSED = 1;

    /// @notice Value indicating contract is paused by owner
    uint64 private constant OWNER_PAUSED = type(uint64).max;

    /// @notice Reporter pause duration (24 hours)
    uint256 private constant REPORTER_PAUSE_DURATION = 24 hours;

    // ============ Mutable State Variables ============

    /// @notice Contract owner address
    /// @dev Packed with pauseUntil in the same storage slot
    address public owner;

    /// @notice Pause state timestamp
    /// @dev NOT_PAUSED (1) = not paused, type(uint64).max = owner paused, timestamp = reporter paused
    /// @dev Packed with owner in the same storage slot
    uint64 public pauseUntil = NOT_PAUSED;

    /// @notice Mapping of reporter addresses
    mapping(address => bool) public reporters;


    // ============ Custom Errors ============

    /// @notice Thrown when contract is already paused
    error AlreadyPaused();

    /// @notice Thrown when contract is already paused by owner
    /// @dev This error is thrown when owner tries to pause an already owner-paused contract
    error AlreadyPausedByOwner();

    /// @notice Thrown when reporter state is already set
    error AlreadySet();

    /// @notice Thrown when caller is not the owner
    error NotOwner();

    /// @notice Thrown when caller is not a reporter
    error NotReporter();

    /// @notice Thrown when contract is not paused
    error NotPaused();

    /// @notice Thrown when zero address is provided
    error ZeroAddress();

    // ============ Events ============

    /// @notice Emitted when ownership is transferred
    /// @param previousOwner Previous owner address
    /// @param newOwner New owner address
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when a reporter is added or removed
    /// @param reporter Reporter address
    /// @param added True if added, false if removed
    event ReporterUpdated(address indexed reporter, bool added);

    /// @notice Emitted when contract is paused by owner
    event OwnerPaused();

    /// @notice Emitted when contract is unpaused by owner
    event OwnerUnpaused();

    /// @notice Emitted when contract is paused by reporter
    /// @param reporter Reporter address that triggered the pause
    /// @param until Timestamp when pause will automatically expire
    event ReporterPaused(address indexed reporter, uint64 until);

    // ============ Modifiers ============

    /// @notice Modifier to ensure contract is not paused
    modifier whenNotPaused() {
        if (block.timestamp < pauseUntil) revert AlreadyPaused();
        _;
    }

    /// @notice Modifier to restrict access to owner only
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Modifier to restrict access to reporters only
    modifier onlyReporter() {
        if (!reporters[msg.sender]) revert NotReporter();
        _;
    }

    // ============ Constructor ============

    /// @notice Constructor to initialize the contract with an owner
    /// @param _owner Initial owner address
    constructor(address _owner) {
        if (_owner == ZERO_ADDRESS) revert ZeroAddress();
        owner = _owner;
    }

    // ============ Owner Functions ============

    /// @notice Transfer ownership to a new address
    /// @dev Only callable by the current owner
    /// @dev Emits OwnerChanged event with previousOwner (current owner) and newOwner
    /// @param newOwner New owner address
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == ZERO_ADDRESS) revert ZeroAddress();
        address previousOwner = owner;
        owner = newOwner;
        emit OwnerChanged(previousOwner, newOwner);
    }

    /// @notice Add or remove a reporter
    /// @dev Only callable by the owner
    /// @param reporter Reporter address to add or remove
    /// @param added True to add, false to remove
    function setReporter(address reporter, bool added) external onlyOwner {
        if (reporter == ZERO_ADDRESS) revert ZeroAddress();
        if (reporters[reporter] == added) revert AlreadySet();
        reporters[reporter] = added;
        emit ReporterUpdated(reporter, added);
    }

    /// @notice Pause the contract (until manually unpaused by owner)
    /// @dev Only callable by the owner
    /// @dev Sets pauseUntil to OWNER_PAUSED (type(uint64).max) to indicate owner pause
    /// @dev Reverts if contract is already paused by owner
    /// @dev Owner can override reporter pause (temporary pause) by calling this function
    function pause() external onlyOwner {
        if(pauseUntil == OWNER_PAUSED) revert AlreadyPausedByOwner();

        pauseUntil = OWNER_PAUSED;
        emit OwnerPaused();
    }

    /// @notice Unpause the contract
    /// @dev Only callable by the owner
    /// @dev Resets pauseUntil to NOT_PAUSED, clearing both owner and reporter pauses
    /// @dev Reverts if contract is not paused
    /// @dev Gas optimized: using NOT_PAUSED (1) avoids expensive zero->non-zero SSTORE on next pause
    function unpause() external onlyOwner {
        if(!isPaused()) revert NotPaused();

        pauseUntil = NOT_PAUSED;
        emit OwnerUnpaused();
    }

    // ============ Reporter Functions ============

    /// @notice Pause the contract for 24 hours
    /// @dev Only callable by a reporter
    /// @dev Reverts if contract is already paused
    /// @dev Sets pauseUntil to block.timestamp + 24 hours
    function pauseByReporter() external onlyReporter whenNotPaused {
        pauseUntil = uint64(block.timestamp + REPORTER_PAUSE_DURATION);
        emit ReporterPaused(msg.sender, pauseUntil);
    }

    // ============ View Functions ============

    /// @notice Check if the contract is currently paused
    /// @return True if paused, false otherwise
    /// @dev Returns true if block.timestamp < pauseUntil
    function isPaused() public view returns (bool) {
        return block.timestamp < pauseUntil;
    }
}