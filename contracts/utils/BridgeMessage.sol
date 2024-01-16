// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title BridgeMessage
/// @notice This library defines the message format and constants for the Sui native bridge.
/// @dev The message prefix and the token decimals are fixed for the Sui bridge.
library BridgeMessage {
    // message Ids
    uint8 public constant TOKEN_TRANSFER = 0;
    uint8 public constant BLOCKLIST = 1;
    uint8 public constant EMERGENCY_OP = 2;
    uint8 public constant BRIDGE_UPGRADE = 3;
    uint8 public constant COMMITTEE_UPGRADE = 4;

    // token Ids
    uint8 public constant SUI = 0;
    uint8 public constant BTC = 1;
    uint8 public constant ETH = 2;
    uint8 public constant USDC = 3;
    uint8 public constant USDT = 4;

    // Sui token decimals
    uint8 public constant SUI_DECIMAL_ON_SUI = 9;
    uint8 public constant BTC_DECIMAL_ON_SUI = 8;
    uint8 public constant ETH_DECIMAL_ON_SUI = 8;
    uint8 public constant USDC_DECIMAL_ON_SUI = 6;
    uint8 public constant USDT_DECIMAL_ON_SUI = 6;

    string public constant MESSAGE_PREFIX = "SUI_NATIVE_BRIDGE";

    /// @dev A struct that represents a bridge message
    /// @param messageType The type of the message, such as token transfer, blocklist, etc.
    /// @param version The version of the message format
    /// @param nonce The nonce of the message, used to prevent replay attacks
    /// @param chainID The chain ID of the source chain
    /// @param payload The payload of the message, which depends on the message type
    struct Message {
        uint8 messageType;
        uint8 version;
        uint64 nonce;
        uint8 chainID;
        bytes payload;
    }

    /// @dev A struct that represents a token transfer payload
    /// @param senderAddressLength The length of the sender address in bytes
    /// @param senderAddress The address of the sender on the source chain
    /// @param targetChain The chain ID of the target chain
    /// @param targetAddressLength The length of the target address in bytes
    /// @param targetAddress The address of the recipient on the target chain
    /// @param tokenId The ID of the token to be transferred
    /// @param amount The amount of the token to be transferred
    struct TokenTransferPayload {
        uint8 senderAddressLength;
        bytes senderAddress;
        uint8 targetChain;
        uint8 targetAddressLength;
        address targetAddress;
        uint8 tokenId;
        uint64 amount;
    }

    /// @dev Encodes a bridge message into bytes, useing abi.encodePacked to concatenate the message fields
    /// @param message The bridge message to be encoded.
    /// @return The encoded message as bytes.
    function encodeMessage(Message memory message) internal pure returns (bytes memory) {
        return abi.encodePacked(
            MESSAGE_PREFIX,
            message.messageType,
            message.version,
            message.nonce,
            message.chainID,
            message.payload
        );
    }

    /// @dev Hash a message using keccak256.
    /// @param message The message to be hashed
    /// @return The hash of the message as bytes32
    function getMessageHash(Message memory message) internal pure returns (bytes32) {
        return keccak256(encodeMessage(message));
    }
}
