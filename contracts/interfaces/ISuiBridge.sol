// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ISuiBridge
/// @dev Interface for the Sui Bridge contract.
interface ISuiBridge {

    /// @dev Emitted when tokens are bridged to Sui.
    /// @param sourceChainId The ID of the source chain.
    /// @param nonce The nonce of the transaction.
    /// @param destinationChainId The ID of the destination chain.
    /// @param tokenCode The code of the token.
    /// @param suiAdjustedAmount The adjusted amount of tokens.
    /// @param sourceAddress The address of the source.
    /// @param targetAddress The address of the target.
    event TokensBridgedToSui(
        uint8 indexed sourceChainID,
        uint64 indexed nonce,
        uint8 indexed destinationChainID,
        uint8 tokenCode,
        uint64 suiAdjustedAmount,
        address sourceAddress,
        bytes targetAddress
    );
}
