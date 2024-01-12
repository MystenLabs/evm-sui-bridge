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
        // TODO: custom decoding for tokenTransferPayload
        (BridgeMessage.TokenTransferPayload memory tokenTransferPayload) =
            abi.decode(payload, (BridgeMessage.TokenTransferPayload));

        return tokenTransferPayload;
    }

    function decodeEmergencyOpPayload(bytes memory payload) public pure returns (bool) {
        (uint256 emergencyOpCode) = abi.decode(payload, (uint256));
        require(emergencyOpCode <= 1, "SuiBridge: Invalid op code");

        if (emergencyOpCode == 0) {
            return true;
        } else if (emergencyOpCode == 1) {
            return false;
        } else {
            revert("Invalid emergency operation code");
        }
    }

    function getMessageHash(Message memory message) public pure returns (bytes32) {
        return keccak256(encodeMessage(message));
    }
}
