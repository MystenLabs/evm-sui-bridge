// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
    event TokensBridgedToSui(
        uint8 tokenCode,
        uint256 amount,
        bytes targetAddress,
        uint8 destinationChainId,
        uint8 sourceChainId,
        uint64 nonce
    );
}
