// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BridgeMessage {
    // message Ids
    uint8 public constant TOKEN_TRANSFER = 0;
    uint8 public constant BLOCKLIST = 1;
    uint8 public constant EMERGENCY_OP = 2;
    uint8 public constant BRIDGE_UPGRADE = 3;
    uint8 public constant COMMITTEE_UPGRADE = 4;
    uint8 public constant UPDATE_DAILY_LIMITS = 5;

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
        return abi.encodePacked(
            MESSAGE_PREFIX,
            message.messageType,
            message.version,
            message.nonce,
            message.chainID,
            message.payload
        );
    }

    function getMessageHash(Message memory message) internal pure returns (bytes32) {
        return keccak256(encodeMessage(message));
    }

    function decodeUpdateDailyBridgeLimits(bytes memory payload) public pure returns (uint256[] memory) {
        (uint256[] memory updatedDailyBridgeLimits) = abi.decode(payload, (uint256[]));
        return updatedDailyBridgeLimits;
    }

    function decodeSingleTokenDailyBridgeLimit(bytes memory payload) public pure returns (uint8, uint256) {
        (uint8 tokenId, uint256 updatedTokenDailyBridgeLimit) = abi.decode(payload, (uint8, uint256));
        return (tokenId, updatedTokenDailyBridgeLimit);
    }
}
