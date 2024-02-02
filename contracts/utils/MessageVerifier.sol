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

    function __MessageVerifier_init(
        address _committee
    ) internal onlyInitializing {
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
            require(
                message.nonce == nonces[message.messageType],
                "MessageVerifier: Invalid nonce"
            );
            nonces[message.messageType]++;
        }
        _;
    }

    /**
- Sui Mainnet ↔ Eth Mainnet
- Sui Testnet ↔ Eth Sepolia
- Sui Testnet ↔ Eth Local Test
- Sui Testnet ↔ Eth Sepolia
- Sui Testnet ↔ Eth Local Test
- Sui LocalNet ↔ Eth Sepolia
- Sui LocalNet ↔ Eth Local Test

0: SUI MAINNET
1:  SUI TESTNET
2:  SUI DEVNET
3: Sui Local Test
10: ETH MAINNET
11: ETH SEPOLIA
12: ETH local test
*/

    modifier verifyRouteLegitimacy(uint8 sourceChainID, uint8 targetChainID) {
        // Check that destination chain ID is valid
        require(
            (sourceChainID == BridgeMessage.SUI &&
                targetChainID == BridgeMessage.ETH) ||
                (sourceChainID == BridgeMessage.SUI &&
                    targetChainID == BridgeMessage.ETH) ||
                (sourceChainID == BridgeMessage.SUI &&
                    targetChainID == BridgeMessage.ETH),
            "MessageVerifier: Invalid destination chain ID"
        );
        _;
    }
}
