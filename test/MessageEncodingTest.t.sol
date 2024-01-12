// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../contracts/interfaces/ISuiBridge.sol";

contract MessageEncodingTest is BridgeBaseTest, ISuiBridge {
    function testEncodeMessage() public {
        bytes memory moveEncodedMessage = abi.encodePacked(
            hex"5355495f4252494447455f4d45535341474500010000000000000000012080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af96010084d71700000000"
        );

        uint64 nonce = 0;
        uint8 suiChainId = 1;

        bytes memory payload = abi.encodePacked(
            hex"2080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af96010084d71700000000"
        );

        bytes memory abiEncodedMessage = BridgeMessage.encodeMessage(
            BridgeMessage.Message({
                messageType: BridgeMessage.TOKEN_TRANSFER,
                version: 1,
                nonce: nonce,
                chainID: suiChainId,
                payload: payload
            })
        );

        assertEq(
            keccak256(moveEncodedMessage),
            keccak256(abiEncodedMessage),
            "Encoded messages do not match"
        );
    }

    function testDecodeTransferTokenPayload() public {
        bytes memory payload = abi.encodePacked(
            hex"2080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af96010084d71700000000"
        );

        BridgeMessage.TokenTransferPayload memory _payload =
            BridgeMessage.decodeTokenTransferPayload(payload);

        assertEq(_payload.senderAddressLength, uint8(32));
        assertEq(
            _payload.senderAddress,
            hex"80ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c"
        );
        assertEq(_payload.targetChain, uint8(11));
        assertEq(_payload.targetAddressLength, uint8(20));

        assertEq(_payload.tokenId, BridgeMessage.BTC);
        // TODO: figure out why the amount is not decoding correctly
        assertEq(_payload.amount, uint64(400_000_000));
    }

    // TODO:
    function testDecodeEmergencyOpPayload() public {}
    // TODO:
    function testDecodeBridgeUpgradePayload() public {}
    // TODO:
    function testDecodeBlocklistPayload() public {}
    // TODO:
    function testDecodeCommitteeUpgradePayload() public {}
}
