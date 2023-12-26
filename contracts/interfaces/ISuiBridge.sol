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
}
