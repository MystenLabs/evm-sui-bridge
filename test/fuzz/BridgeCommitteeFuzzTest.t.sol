// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";

contract BridgeCommitteeFuzzTest is BridgeBaseFuzzTest {
    function setUp() public {
        setUpBridgeFuzzTest();
    }

    function testFuzz_verifyMessageSignatures(uint8 numSigners, uint8 messageType) public {
        vm.assume(numSigners > 0 && numSigners <= N);
        messageType =
            uint8(bound(messageType, BridgeMessage.TOKEN_TRANSFER, BridgeMessage.BLOCKLIST));
        bytes memory payload = "0x";
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: messageType,
            version: 1,
            nonce: 1,
            chainID: BridgeBaseFuzzTest.chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try bridgeCommittee.verifySignatures(signatures, message) {
            // The call was successful
            signaturesValid = true;
        } catch Error(string memory) {
            signaturesValid = false;
        } catch (bytes memory) {
            signaturesValid = false;
        }

        if (signaturesValid) {
            bridgeCommittee.verifySignatures(signatures, message);
        } else {
            // Expect a revert
            vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
            bridgeCommittee.verifySignatures(signatures, message);
        }
    }

    function testFuzz_updateBlocklistWithSignatures(
        uint8 numSigners,
        uint8 isBlocklisted,
        uint8 blocklistAddressesPos
    ) public {
        vm.assume(numSigners > 0 && numSigners <= N);
        vm.assume(blocklistAddressesPos >= 0 && blocklistAddressesPos < N);

        // Create a blocklist payload
        isBlocklisted = uint8(bound(isBlocklisted, 0, 1));
        bytes memory isBlocklistedBytes = isBlocklisted == 0 ? bytes(hex"0000") : bytes(hex"0001");

        bytes memory payload =
            abi.encodePacked(isBlocklistedBytes, _committeeMemebers[blocklistAddressesPos]);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: BridgeBaseFuzzTest.chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try bridgeCommittee.verifySignatures(signatures, message) {
            // The call was successful
            signaturesValid = true;
        } catch Error(string memory) {
            signaturesValid = false;
        } catch (bytes memory) {
            signaturesValid = false;
        }

        if (signaturesValid) {
            bridgeCommittee.updateBlocklistWithSignatures(signatures, message);
        } else {
            // Expect a revert
            vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
            bridgeCommittee.updateBlocklistWithSignatures(signatures, message);
        }
    }
}
