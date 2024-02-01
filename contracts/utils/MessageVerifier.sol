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

    function __MessageVerifier_init(address _committee) internal onlyInitializing {
        committee = IBridgeCommittee(_committee);
    }

    modifier verifySignaturesAndNonce(
        BridgeMessage.Message memory message,
        bytes[] memory signatures,
        uint8 messageType
    ) {
        // verify message type
        committee.verifyMessageSignatures(signatures, message, messageType);

        // increment message type nonce
        if (messageType != BridgeMessage.TOKEN_TRANSFER) {
            require(message.nonce == nonces[message.messageType], "MessageVerifier: Invalid nonce");
            nonces[message.messageType]++;
        }
        _;
    }

    modifier verifyDestinationChainID(uint8 destinationChainID) {
        // Check that destination chain ID is valid
        require(
            destinationChainID == BridgeMessage.SUI ||
                destinationChainID == BridgeMessage.BTC ||
                destinationChainID == BridgeMessage.ETH ||
                destinationChainID == BridgeMessage.USDC ||
                destinationChainID == BridgeMessage.USDT,
            "MessageVerifier: Invalid destination chain ID"
        );
        _;
    }
}
