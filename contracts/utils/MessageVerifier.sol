// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IBridgeCommittee.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title MessageVerifier
/// @dev Abstract contract that enables the verification of message signatures and management
/// of message nonces.
abstract contract MessageVerifier is Initializable {
    IBridgeCommittee public committee;
    // messageType => nonce
    mapping(uint8 => uint64) public nonces;

    bool private _upgradeAuthorized;

    function __MessageVerifier_init(address _committee) internal onlyInitializing {
        committee = IBridgeCommittee(_committee);
    }

    modifier verifySignatures(
        BridgeMessage.Message memory message,
        bytes[] memory signatures,
        uint8 messageType
    ) {
        // verify message type
        committee.verifyMessageSignatures(signatures, message, messageType);

        // increment message type nonce
        if (messageType != BridgeMessage.TOKEN_TRANSFER) {
            require(message.nonce == nonces[message.messageType], "SuiBridge: Invalid nonce");
            nonces[message.messageType]++;
        }
        _;
    }
}
