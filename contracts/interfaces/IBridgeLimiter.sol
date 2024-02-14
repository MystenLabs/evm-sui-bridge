// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IBridgeLimiter
/// @notice Interface for the BridgeLimiter contract.
interface IBridgeLimiter {
    /// @notice Updates the bridge transfers for a specific token ID and amount. Only the contract
    /// owner can call this function (intended to be the SuiBridge contract).
    /// @dev The amount must be greater than 0 and must not exceed the rolling window limit.
    /// @param tokenID The ID of the token.
    /// @param amount The amount of tokens to be transferred.
    function updateBridgeTransfers(uint8 tokenID, uint256 amount) external;

    /// @notice Returns whether the total amount, including the given token amount, will exceed the totalLimit.
    /// @dev The function will calculate the given token amount in USD.
    /// @param tokenID The ID of the token.
    /// @param amount The amount of the token.
    /// @return boolean indicating whether the total amount will exceed the limit.
    function willAmountExceedLimit(uint8 tokenID, uint256 amount) external view returns (bool);
}
