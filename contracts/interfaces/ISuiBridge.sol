// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
    event TokensBridgedToSui(
        uint256 tokenCode,
        uint256 amount,
        bytes targetAddress,
        uint256 destinationChainId,
        uint256 nonce
    );

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
}
