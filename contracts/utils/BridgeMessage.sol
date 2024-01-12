// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

    function encodeMessage(Message memory message) internal pure returns (bytes memory) {
        bytes memory baseMessage = abi.encodePacked(
            MESSAGE_PREFIX, message.messageType, message.version, message.nonce, message.chainID
        );
        return bytes.concat(baseMessage, message.payload);
    }

    function computeHash(Message memory message) public pure returns (bytes32) {
        return keccak256(encodeMessage(message));
    }

    function decodeUpgradePayload(bytes memory payload)
        public
        pure
        returns (address, bytes memory)
    {
        (address implementationAddress, bytes memory callData) =
            abi.decode(payload, (address, bytes));
        return (implementationAddress, callData);
    }

    function decodeTokenTransferPayload(bytes memory payload)
        public
        pure
        returns (BridgeMessage.TokenTransferPayload memory)
    {
        require(payload.length >= 1, "BridgeMessage: Payload too short");

        uint8 senderAddressLength = uint8(payload[0]);
        require(
            payload.length >= 1 + senderAddressLength + 20 + 1 + 1 + 8,
            "BridgeMessage: Payload too short"
        );

        bytes memory senderAddress = new bytes(senderAddressLength);
        for (uint256 i = 0; i < senderAddressLength; i++) {
            senderAddress[i] = payload[i + 1];
        }

        uint8 targetChain = uint8(payload[1 + senderAddressLength]);
        uint8 targetAddressLength = uint8(payload[1 + senderAddressLength + 1]);
        require(targetAddressLength == 20, "BridgeMessage: Invalid target address length");

        address targetAddress;
        uint8 tokenId;
        uint64 amount;

        // calculate offsets for targetAddress, tokenId, and amount
        assembly {
            targetAddress := mload(add(payload, add(0x22, senderAddressLength)))
        }

        uint256 tokenIdOffset = 1 + senderAddressLength + 1 + 1 + 20;
        tokenId = uint8(payload[tokenIdOffset]);

        uint256 amountOffset = tokenIdOffset + 1;
        assembly {
            amount := mload(add(payload, add(amountOffset, 0x20)))
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

    function decodeEmergencyOpPayload(bytes memory payload) public pure returns (bool) {
        (uint256 emergencyOpCode) = abi.decode(payload, (uint256));
        require(emergencyOpCode <= 1, "BridgeMessage: Invalid op code");

        if (emergencyOpCode == 0) {
            return true;
        } else if (emergencyOpCode == 1) {
            return false;
        } else {
            revert("BridgeMessage: Invalid emergency operation code");
        }
    }

    function decodeBlocklistPayload(bytes memory payload)
        public
        pure
        returns (bool, address[] memory)
    {
        (uint8 blocklistType, address[] memory validators) = abi.decode(payload, (uint8, address[]));
        // blocklistType: 0 = blocklist, 1 = unblocklist
        bool blocklisted = (blocklistType == 0) ? true : false;
        return (blocklisted, validators);
    }
}
