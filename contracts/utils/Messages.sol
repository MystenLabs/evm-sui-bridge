// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Messages {
    // message Ids
    uint8 public constant TOKEN_TRANSFER = 0;
    uint8 public constant BLOCKLIST = 1;
    uint8 public constant EMERGENCY_OP = 2;
    uint8 public constant BRIDGE_UPGRADE = 3;
    uint8 public constant COMMITTEE_UPGRADE = 4;

    // token Ids
    uint256 public constant SUI = 0;
    uint256 public constant BTC = 1;
    uint256 public constant ETH = 2;
    uint256 public constant USDC = 3;
    uint256 public constant USDT = 4;

    // constant

    uint256 public constant SIGNATURE_SIZE = 65;

    struct Message {
        uint8 messageType;
        uint8 version;
        uint64 nonce;
        uint8 chainID;
        bytes payload;
    }

    struct TokenTransferPayload {
        uint8 sourceChainTxIdLength;
        uint8 sourceChainTxId;
        uint8 sourceChainEventIndex;
        uint8 senderAddressLength;
        bytes senderAddress;
        uint8 targetChain;
        uint8 targetAddressLength;
        address targetAddress;
        uint8 tokenType;
        uint64 amount;
    }

    function decodeMessage(bytes memory message) internal pure returns (Message memory) {
        // Check that the message is not empty
        require(message.length > 0, "Empty message");

        // decode nonce, version, and type from message
        (uint8 messageType, uint8 version, uint64 nonce, uint8 chainId, bytes memory payload)
        = abi.decode(message, (uint8, uint8, uint64, uint8, bytes));

        return Message(messageType, version, nonce, chainId, payload);
    }

    function decodeEmergencyOpPayload(bytes memory payload) internal pure returns (bool) {
        (uint256 emergencyOpCode) = abi.decode(payload, (uint256));
        require(emergencyOpCode <= 1, "SuiBridge: Invalid op code");

        if (emergencyOpCode == 0) return true;
        else if (emergencyOpCode == 1) return false;
    }

    function decodeUpgradePayload(bytes memory payload) internal pure returns (address) {
        (address implementationAddress) = abi.decode(payload, (address));
        return implementationAddress;
    }

    function decodeBlocklistPayload(bytes memory payload)
        internal
        pure
        returns (bool, address[] memory)
    {
        (uint256 blocklistType, address[] memory validators) =
            abi.decode(payload, (uint256, address[]));
        bool blocklisted = (blocklistType == 0) ? true : false;
        return (blocklisted, validators);
    }

    function decodeTokenTransferPayload(bytes memory payload)
        internal
        pure
        returns (TokenTransferPayload memory)
    {
        (TokenTransferPayload memory tokenTransferPayload) =
            abi.decode(payload, (TokenTransferPayload));

        return tokenTransferPayload;
    }
}