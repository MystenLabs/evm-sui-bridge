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
    uint8 public constant UPDATE_BRIDGE_LIMIT = 3;
    uint8 public constant UPDATE_ASSET_PRICE = 4;
    uint8 public constant BRIDGE_UPGRADE = 5;
    uint8 public constant COMMITTEE_UPGRADE = 6;
    uint8 public constant LIMITER_UPGRADE = 7;

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

    // Message type stake requirements
    uint32 public constant TRANSFER_STAKE_REQUIRED = 3334;
    uint32 public constant FREEZING_STAKE_REQUIRED = 450;
    uint32 public constant UNFREEZING_STAKE_REQUIRED = 5001;
    uint32 public constant BRIDGE_UPGRADE_STAKE_REQUIRED = 5001;
    uint16 public constant BLOCKLIST_STAKE_REQUIRED = 5001;
    uint16 public constant COMMITTEE_UPGRADE_STAKE_REQUIRED = 5001;
    uint32 public constant ASSET_LIMIT_STAKE_REQUIRED = 5001;

    string public constant MESSAGE_PREFIX = "SUI_BRIDGE_MESSAGE";

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

    // TODO: add unit test for this function
    /// @dev Encodes a bridge message into bytes, useing abi.encodePacked to concatenate the message fields
    /// @param message The bridge message to be encoded.
    /// @return The encoded message as bytes.
    function encodeMessage(Message memory message) internal pure returns (bytes memory) {
        bytes memory prefixTypeAndVersion =
            abi.encodePacked(MESSAGE_PREFIX, message.messageType, message.version);
        bytes memory bigEndianNonce = abi.encodePacked(message.nonce);
        bytes memory littleEndianNonce = bigEndiantToLittleEndian(bigEndianNonce);
        bytes memory chainID = abi.encodePacked(message.chainID);
        return bytes.concat(prefixTypeAndVersion, littleEndianNonce, chainID, message.payload);
    }

    // TODO: replace with assembly?
    function bigEndiantToLittleEndian(bytes memory message) internal pure returns (bytes memory) {
        bytes memory littleEndianMessage = new bytes(message.length);
        for (uint256 i = 0; i < message.length; i++) {
            littleEndianMessage[message.length - i - 1] = message[i];
        }
        return littleEndianMessage;
    }

    function computeHash(Message memory message) internal pure returns (bytes32) {
        return keccak256(encodeMessage(message));
    }

    // TODO: Check if the values for UPDATE_BRIDGE_LIMIT, UPDATE_ASSET_PRICE, and COMMITTEE_UPGRADE are correct
    function getRequiredStake(Message memory message) internal pure returns (uint32) {
        if (message.messageType == TOKEN_TRANSFER) {
            return TRANSFER_STAKE_REQUIRED;
        } else if (message.messageType == BLOCKLIST) {
            return BLOCKLIST_STAKE_REQUIRED;
        } else if (message.messageType == EMERGENCY_OP) {
            bool isFreezing = decodeEmergencyOpPayload(message.payload);
            if (isFreezing) return FREEZING_STAKE_REQUIRED;
            return UNFREEZING_STAKE_REQUIRED;
        } else if (message.messageType == UPDATE_BRIDGE_LIMIT) {
            return ASSET_LIMIT_STAKE_REQUIRED;
        } else if (message.messageType == UPDATE_ASSET_PRICE) {
            return ASSET_LIMIT_STAKE_REQUIRED;
        } else if (message.messageType == BRIDGE_UPGRADE) {
            return BRIDGE_UPGRADE_STAKE_REQUIRED;
        } else if (message.messageType == COMMITTEE_UPGRADE) {
            return COMMITTEE_UPGRADE_STAKE_REQUIRED;
        } else if (message.messageType == LIMITER_UPGRADE) {
            return ASSET_LIMIT_STAKE_REQUIRED;
        } else {
            revert("BridgeMessage: Invalid message type");
        }
    }

    // TODO: add unit tests
    function decodeUpgradePayload(bytes memory payload)
        internal
        pure
        returns (address, bytes memory)
    {
        (address implementationAddress, bytes memory callData) =
            abi.decode(payload, (address, bytes));
        return (implementationAddress, callData);
    }

    function decodeTokenTransferPayload(bytes memory payload)
        internal
        pure
        returns (BridgeMessage.TokenTransferPayload memory)
    {
        // TODO: if we support multi chains, the source address length may vary

        require(payload.length == 64, "BridgeMessage: TokenTransferPayload must be 64 bytes");

        uint8 senderAddressLength = uint8(payload[0]);

        bytes memory senderAddress = new bytes(senderAddressLength);
        for (uint256 i = 0; i < senderAddressLength; i++) {
            senderAddress[i] = payload[i + 1];
        }

        uint8 targetChain = uint8(payload[1 + senderAddressLength]);

        // TODO I think we want to assert chainID here.
        // should do this in message verification not decoding

        uint8 targetAddressLength = uint8(payload[1 + senderAddressLength + 1]);
        require(
            targetAddressLength == 20,
            "BridgeMessage: Invalid target address length, EVM address must be 20 bytes"
        );

        // targetAddress starts from index 35
        uint160 addr = 0;
        for (uint256 i = 0; i < 20; i++) {
            addr = uint160(addr) | (uint160(uint8(payload[i + 35])) << uint160(((19 - i) * 8)));
        }
        address targetAddress = address(addr);

        uint256 tokenIdOffset = 1 + senderAddressLength + 1 + 1 + 20;
        uint8 tokenId = uint8(payload[tokenIdOffset]);

        uint64 amount;
        uint8 offset;
        for (uint256 i = payload.length - 8; i < payload.length; i++) {
            amount |= uint64(uint8(payload[i])) << (offset * 8);
            offset++;
        }

        return TokenTransferPayload(
            senderAddressLength,
            senderAddress,
            targetChain,
            targetAddressLength,
            targetAddress,
            tokenId,
            amount
        );
    }

    function decodeEmergencyOpPayload(bytes memory payload) internal pure returns (bool) {
        (uint8 emergencyOpCode) = abi.decode(payload, (uint8));
        require(emergencyOpCode <= 1, "BridgeMessage: Invalid op code");
        return emergencyOpCode == 0 ? true : false;
    }

    function decodeBlocklistPayload(bytes memory payload)
        internal
        pure
        returns (bool, address[] memory)
    {
        (uint8 blocklistType, address[] memory validators) = abi.decode(payload, (uint8, address[]));
        // blocklistType: 0 = blocklist, 1 = unblocklist
        bool blocklisted = (blocklistType == 0) ? true : false;
        return (blocklisted, validators);
    }

    // TODO: add unit test
    function decodeUpdateAssetPayload(bytes memory payload)
        internal
        pure
        returns (uint8, uint256)
    {
        (uint8 tokenId, uint256 price) = abi.decode(payload, (uint8, uint256));
        return (tokenId, price);
    }

    // TODO: add unit test
    function decodeUpdateLimitPayload(bytes memory payload) internal pure returns (uint256) {
        (uint256 newLimit) = abi.decode(payload, (uint256));
        return newLimit;
    }
}
