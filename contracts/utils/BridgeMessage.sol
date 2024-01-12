// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "forge-std/console.sol";

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

    // Token Transfer Payload Format:
    // [sender_address_length:u8]
    // [sender_address: byte[]]
    // [target_chain:u8]
    // [target_address_length:u8]
    // [target_address: byte[]]
    // [token_type:u8]
    // [amount:u64]
    // Eth address is 20 bytes, Sui Address is 32 bytes, in total the payload must be 64 bytes
    function decodeTokenTransferPayload(bytes memory payload)
        public
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

        uint8 targetAddressLength = uint8(payload[1 + senderAddressLength + 1]);
        require(targetAddressLength == 20, "BridgeMessage: Invalid target address length, Eth address must be 20 bytes");

        // targetAddress starts from index 35
        uint160 addr = 0;
        for (uint256 i = 0; i < 20; i++) {
            addr = uint160(addr) | (uint160(uint8(payload[i + 35])) << ((19 - i) * 8));
        }
        address targetAddress = address(addr);

        uint256 tokenIdOffset = 1 + senderAddressLength + 1 + 1 + 20;
        uint8 tokenId = uint8(payload[tokenIdOffset]);

        uint64 value;
        uint8 offset;
        for (uint256 i = payload.length - 8; i < payload.length; i++) {
            value |= uint64(uint8(payload[i])) << (offset * 8);
            offset++;
        }
        uint64 amount = value;

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
