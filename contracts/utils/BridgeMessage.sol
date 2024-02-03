// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
    uint8 public constant UPGRADE = 5;

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
    uint32 public constant UPGRADE_STAKE_REQUIRED = 5001;
    uint16 public constant BLOCKLIST_STAKE_REQUIRED = 5001;
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

    /// @dev Encodes a bridge message into bytes, using abi.encodePacked to concatenate the message fields
    /// @param message The bridge message to be encoded.
    /// @return The encoded message as bytes.
    function encodeMessage(Message memory message) internal pure returns (bytes memory) {
        bytes memory prefixTypeAndVersion =
            abi.encodePacked(MESSAGE_PREFIX, message.messageType, message.version);
        bytes memory nonce = abi.encodePacked(message.nonce);
        bytes memory chainID = abi.encodePacked(message.chainID);
        return bytes.concat(prefixTypeAndVersion, nonce, chainID, message.payload);
    }

    function computeHash(Message memory message) internal pure returns (bytes32) {
        return keccak256(encodeMessage(message));
    }

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
        } else if (message.messageType == UPGRADE) {
            return UPGRADE_STAKE_REQUIRED;
        } else {
            revert("BridgeMessage: Invalid message type");
        }
    }

    // TokenTransfer payload is 64 bytes.
    // byte 0       : sender address length
    // bytes 1-32   : sender address (as we only support Sui now, it has to be 32 bytes long)
    // bytes 33     : target chain id
    // byte 34      : target address length
    // bytes 35-54  : target address
    // byte 55      : token id
    // bytes 56-63  : amount
    function decodeTokenTransferPayload(bytes memory payload)
        internal
        pure
        returns (BridgeMessage.TokenTransferPayload memory)
    {
        require(payload.length == 64, "BridgeMessage: TokenTransferPayload must be 64 bytes");

        uint8 senderAddressLength = uint8(payload[0]);

        require(
            senderAddressLength == 32,
            "BridgeMessage: Invalid sender address length, Sui address must be 32 bytes"
        );

        // used to offset already read bytes
        uint8 offset = 1;

        // extract sender address from payload bytes 1-32
        bytes memory senderAddress = new bytes(senderAddressLength);
        for (uint256 i = 0; i < senderAddressLength; i++) {
            senderAddress[i] = payload[i + offset];
        }

        // move offset past the sender address length
        offset += senderAddressLength;

        // target chain is a single byte
        uint8 targetChain = uint8(payload[offset++]);

        // target address length is a single byte
        uint8 targetAddressLength = uint8(payload[offset++]);
        require(
            targetAddressLength == 20,
            "BridgeMessage: Invalid target address length, EVM address must be 20 bytes"
        );

        // extract target address from payload (35-54)
        address targetAddress;

        // why `add(targetAddressLength, offset)`?
        // At this point, offset = 35, targetAddressLength = 20. `mload(add(payload, 55))`
        // reads the next 32 bytes from bytes 23 in paylod, because the first 32 bytes
        // of payload stores its length. So in reality, bytes 23 - 54 is loaded. During
        // casting to address (20 bytes), the least sigificiant bytes are retained, namely
        // `targetAddress` is bytes 35-54
        assembly {
            targetAddress := mload(add(payload, add(targetAddressLength, offset)))
        }

        // move offset past the target address length
        offset += targetAddressLength;

        // token id is a single byte
        uint8 tokenId = uint8(payload[offset++]);

        // extract amount from payload
        uint64 amount;
        uint8 amountLength = 8; // uint64 = 8 bits

        // Why `add(amountLength, offset)`?
        // At this point, offset = 56, amountLength = 8. `mload(add(payload, 64))`
        // reads the next 32 bytes from bytes 32 in paylod, because the first 32 bytes
        // of payload stores its length. So in reality, bytes 32 - 63 is loaded. During
        // casting to uint64 (8 bytes), the least sigificiant bytes are retained, namely
        // `targetAddress` is bytes 56-63
        assembly {
            amount := mload(add(payload, add(amountLength, offset)))
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

    function decodeBlocklistPayload(bytes memory payload)
        internal
        pure
        returns (bool, address[] memory)
    {
        // uint8 blocklistType = uint8(payload[0]);
        // uint8 membersLength = uint8(payload[1]);
        // address[] memory members = new address[](membersLength);
        // uint8 offset;
        // for (uint8 i = 0; i < membersLength; i++) {
        //     address member;
        //     assembly {
        //         member := mload(add(payload, 0x20))
        //     }
        //     members[i] = member;
        //     offset += 20;
        // }

        // // blocklistType: 0 = blocklist, 1 = unblocklist
        // bool blocklisted = (blocklistType == 0) ? true : false;
        // return (blocklisted, members);
        (uint8 blocklistType, address[] memory members) = abi.decode(payload, (uint8, address[]));
        return (blocklistType == 0 ? true : false, members);
    }

    function decodeEmergencyOpPayload(bytes memory payload) internal pure returns (bool) {
        (uint8 emergencyOpCode) = abi.decode(payload, (uint8));
        require(emergencyOpCode <= 1, "BridgeMessage: Invalid op code");
        return emergencyOpCode == 0 ? true : false;
    }

    function decodeUpdateLimitPayload(bytes memory payload) internal pure returns (uint256) {
        (uint256 newLimit) = abi.decode(payload, (uint256));
        return newLimit;
    }

    function decodeUpdateAssetPayload(bytes memory payload)
        internal
        pure
        returns (uint8, uint256)
    {
        (uint8 tokenId, uint256 price) = abi.decode(payload, (uint8, uint256));
        return (tokenId, price);
    }

    function decodeUpgradePayload(bytes memory payload)
        internal
        pure
        returns (address, address, bytes memory)
    {
        (address proxy, address implementation, bytes memory callData) =
            abi.decode(payload, (address, address, bytes));
        return (proxy, implementation, callData);
    }
}
