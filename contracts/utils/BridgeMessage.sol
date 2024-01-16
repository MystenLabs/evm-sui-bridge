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

    // TODO: add unit test for this function
    function encodeMessage(Message memory message) internal pure returns (bytes memory) {
        bytes memory prefixTypeAndVersion = abi.encodePacked(
            MESSAGE_PREFIX, message.messageType, message.version
        );
        bytes memory bigEndianNonce = abi.encodePacked(message.nonce);
        bytes memory littleEndianNonce = bigEndiantToLittleEndian(bigEndianNonce);
        bytes memory chainID = abi.encodePacked(
            message.chainID
        );
        return bytes.concat(prefixTypeAndVersion, littleEndianNonce, chainID, message.payload);
    }

    // TODO: replace with assembly?
    function bigEndiantToLittleEndian(bytes memory message) internal pure returns (bytes memory) {
        bytes memory littleEndianMessage = new bytes(message.length);
        for (uint i = 0; i < message.length; i++) {
            littleEndianMessage[message.length - i - 1] = message[i];
        }
        return littleEndianMessage;
    }

    function computeHash(Message memory message) internal pure returns (bytes32) {
        return keccak256(encodeMessage(message));
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

    // TODO: add unit tests
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

        uint8 targetAddressLength = uint8(payload[1 + senderAddressLength + 1]);
        require(
            targetAddressLength == 20,
            "BridgeMessage: Invalid target address length, Eth address must be 20 bytes"
        );

        // targetAddress starts from index 35
        uint160 addr = 0;
        for (uint256 i = 0; i < 20; i++) {
            addr = uint160(addr) | (uint160(uint8(payload[i + 35])) << uint160(((19 - i) * 8)));
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
}
