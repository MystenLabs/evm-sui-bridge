// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    struct Message {
        uint8 messageType;
        uint8 version;
        uint64 nonce;
        uint8 chainID;
        bytes payload;
    }

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
        } else if (message.messageType == BRIDGE_UPGRADE) {
            return BRIDGE_UPGRADE_STAKE_REQUIRED;
        } else if (message.messageType == COMMITTEE_UPGRADE) {
            return COMMITTEE_UPGRADE_STAKE_REQUIRED;
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
        require(payload.length == 64, "BridgeMessage: TokenTransferPayload must be 64 bytes");

        uint8 senderAddressLength = uint8(payload[0]);

        // used to offset already read bytes
        uint8 offset = 1;

        // extract sender address from payload
        bytes memory senderAddress = new bytes(senderAddressLength);
        for (uint256 i = 0; i < senderAddressLength; i++) {
            senderAddress[i] = payload[i + offset];
        }

        // move offset past the sender address length
        offset += senderAddressLength;

        // target chain is a single byte
        uint8 targetChain = uint8(payload[offset++]);

        // target address is a single byte
        uint8 targetAddressLength = uint8(payload[offset++]);
        require(
            targetAddressLength == 20,
            "BridgeMessage: Invalid target address length, EVM address must be 20 bytes"
        );

        // extract target address from payload
        address targetAddress;
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

    // TODO: add unit test
    function decodeEmergencyOpPayload(bytes memory payload) internal pure returns (bool) {
        (uint8 emergencyOpCode) = abi.decode(payload, (uint8));
        require(emergencyOpCode <= 1, "BridgeMessage: Invalid op code");

        if (emergencyOpCode == 0) {
            return true;
        } else if (emergencyOpCode == 1) {
            return false;
        } else {
            revert("BridgeMessage: Invalid emergency operation code");
        }
    }

    // TODO: add unit test
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
