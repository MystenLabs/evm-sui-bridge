// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
        // 20: sender length 1 bytes
        // 80ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c: sender 32 bytes
        // 0b: target chain 1 bytes
        // 14: target adress length 1 bytes
        // b18f79fe671db47393315ffdb377da4ea1b7af96: target address 20 bytes
        // 02: token id 1 byte
        // 000000c70432b1dd: amount 8 bytes
        bytes memory payload =
            hex"2080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af9602000000c70432b1dd";

        BridgeMessage.TokenTransferPayload memory _payload =
            BridgeMessage.decodeTokenTransferPayload(payload);

        assertEq(_payload.senderAddressLength, uint8(32));
        assertEq(
            _payload.senderAddress,
            hex"80ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c"
        );
        assertEq(_payload.targetChain, uint8(11));
        assertEq(_payload.targetAddressLength, uint8(20));
        assertEq(_payload.targetAddress, 0xb18f79Fe671db47393315fFDB377Da4Ea1B7AF96);
        assertEq(_payload.tokenId, BridgeMessage.ETH);
        assertEq(_payload.amount, uint64(854768923101));
    }

    // Waiting for move generated payloads to be generated

    // TODO:
    function testDecodeEmergencyOpPayload() public {}
    // TODO:
    function testDecodeUpgradePayload() public {}
    // TODO:
    function testDecodeBlocklistPayload() public {}
    // TODO:
    function testDecodeUpdateAssetPayload() public {}
    // TODO:
    function testDecodeUpdateLimitPayload() public {}
}
