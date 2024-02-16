// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISuiBridge
/// @dev Interface for the Sui Bridge contract.
interface ISuiBridge {
    /// @dev Emitted when tokens are deposited to be bridged.
    /// @param sourceChainID The ID of the source chain.
    /// @param nonce The nonce of the transaction.
    /// @param destinationChainID The ID of the destination chain.
    /// @param tokenCode The code of the token.
    /// @param suiAdjustedAmount The adjusted amount of tokens.
    /// @param sourceAddress The address of the source.
    /// @param targetAddress The address of the target.
    event TokensDeposited(
        uint8 indexed sourceChainID,
        uint64 indexed nonce,
        uint8 indexed destinationChainID,
        uint8 tokenCode,
        uint64 suiAdjustedAmount,
        address sourceAddress,
        bytes targetAddress
    );

    /// @dev Emitted when bridged tokens are transferred to the recipient address.
    /// @param sourceChainID The ID of the source chain.
    /// @param nonce The nonce of the transaction.
    /// @param tokenID The code of the token.
    /// @param amount The amount of tokens transferred.
    event BridgedTokensTransferred(
        uint8 indexed sourceChainID, uint64 indexed nonce, uint8 tokenID, uint256 amount
    );
}
