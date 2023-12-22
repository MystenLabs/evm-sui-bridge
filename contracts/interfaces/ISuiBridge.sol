// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
    struct Message {
        uint256 nonce;
        uint256 version;
        uint256 messageType;
        uint256 sourceChain;
        uint256 sourceChainTxIdLength;
        uint256 sourceChainTxId;
        uint256 sourceChainEventIndex;
        uint256 senderAddressLength;
        bytes senderAddress;
        uint256 targetChain;
        uint256 targetAddressLength;
        address targetAddress;
        uint256 tokenType;
        uint256 amount;
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
