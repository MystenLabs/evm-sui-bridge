// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IBridgeCommittee.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract CommitteeOwned is Initializable {
    IBridgeCommittee public committee;
    // messageType => nonce
    mapping(uint8 => uint64) public nonces;

    function __CommitteeOwned_init(address _committee) internal onlyInitializing {
        committee = IBridgeCommittee(_committee);
    }

    modifier validateMessage(
        BridgeMessage.Message memory message,
        bytes[] memory signatures,
        uint8 messageType
    ) {
        // verify message type
        committee.verifyMessageSignatures(signatures, message, messageType);

        // increment message type nonce
        nonces[message.messageType]++;
        _;
    }

    modifier nonceInOrder(BridgeMessage.Message memory message) {
        require(message.nonce == nonces[message.messageType], "SuiBridge: Invalid nonce");
        _;
    }
}
