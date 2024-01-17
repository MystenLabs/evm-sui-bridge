// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
    event TokensBridgedToSui(
        uint8 indexed sourceChainID,
        uint64 indexed nonce,
        uint8 indexed destinationChainID,
        uint8 tokenCode,
        uint64 suiAdjustedAmount,
        address sourceAddress,
        bytes targetAddress
    );
}
