// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IBridgeLimiter
/// @dev Interface for a bridge limiter contract that imposes limits on token bridging operations.
interface IBridgeLimiter {
    /// @dev Updates the daily amount of tokens bridged for the specified token ID.
    /// @param tokenId The ID of the token being bridged.
    /// @param amount The amount of tokens being bridged.
    function updateBridgeTransfers(uint8 tokenId, uint256 amount) external;

    function willAmountExceedLimit(uint8 tokenId, uint256 amount) external view returns (bool);

    /// @dev Emitted when the hourly transfer amount is updated.
    /// @param hourUpdated The hour that was updated.
    /// @param amount The amount in USD transferred.
    event HourlyTransferAmountUpdated(uint32 hourUpdated, uint256 amount);

    /// @dev Emitted when the asset price is updated.
    /// @param tokenId The ID of the token.
    /// @param price The price of the token in USD.
    event AssetPriceUpdated(uint8 tokenId, uint64 price);

    /// @dev Emitted when the total limit is updated.
    /// @param sourceChainID The ID of the source chain.
    /// @param newLimit The new limit in USD.
    event LimitUpdated(uint8 sourceChainID, uint64 newLimit);
}
