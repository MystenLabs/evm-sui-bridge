// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
    struct Message {
        uint8 messageType;
        uint8 version;
        uint64 nonce;
        uint8 sourceChain;
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

    function submitMessage(bytes memory message) external;

    function transferOwnership(address newOwner) external;

    event TokensBridgedToSui(
        uint256 tokenCode,
        uint256 amount,
        bytes targetAddress,
        uint256 destinationChainId,
        uint256 nonce
    );
}
