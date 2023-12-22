// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
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
