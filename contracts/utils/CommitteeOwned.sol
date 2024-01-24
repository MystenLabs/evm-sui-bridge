// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IBridgeCommittee.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title CommitteeOwned
/// @dev Abstract contract that provides ownership functionality to a committee.
abstract contract CommitteeOwned is Initializable {
    IBridgeCommittee public committee;
    // messageType => nonce
    mapping(uint8 messageType => uint64 nonce) public nonces;

    /// @dev Initializes the contract with the specified committee address.
    /// @param _committee The address of the committee contract.
    function __CommitteeOwned_init(address _committee) internal onlyInitializing {
        committee = IBridgeCommittee(_committee);
    }

    /// @dev Modifier to validate a bridge message. It verifies the message type and the signatures using the committee's verifyMessageSignatures function. It also increments the message type nonce.
    /// @param message The bridge message to validate.
    /// @param signatures The signatures of the message.
    /// @param messageType The type of the message.
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

    /// @dev Modifier to check if the nonce in the given message is in order. It verifies if the nonce matches the expected nonce for the given message type. If the nonce is not in order, it reverts with an "Invalid nonce" error message. Otherwise, it continues with the execution of the function.
    /// @param message The BridgeMessage.Message struct containing the nonce and message type.
    modifier nonceInOrder(BridgeMessage.Message memory message) {
        require(message.nonce == nonces[message.messageType], "CommitteeOwned: Invalid nonce");
        _;
    }
}
