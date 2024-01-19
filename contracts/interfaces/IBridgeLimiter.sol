// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IBridgeLimiter
/// @dev Interface for a bridge limiter contract that imposes limits on token bridging operations.
interface IBridgeLimiter {
    /// @dev Updates the daily amount of tokens bridged for the specified token ID.
    /// @param tokenId The ID of the token being bridged.
    /// @param amount The amount of tokens being bridged.
    function updateBridgeTransfers(uint8 tokenId, uint256 amount) external;
}