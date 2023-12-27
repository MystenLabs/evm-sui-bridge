// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";
import "../contracts/utils/Messages.sol";

contract BridgeCommitteeTest is BridgeBaseTest {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testBridgeCommitteeInitialization() public {
        assertEq(committee.committee(committeeMemberA), 1000);
        assertEq(committee.committee(committeeMemberB), 1000);
        assertEq(committee.committee(committeeMemberC), 1000);
        assertEq(committee.committee(committeeMemberD), 2000);
    }

    function testVerifyMessageSignaturesWithValidSignatures() public {
        // Create a message and hash it
        Messages.Message memory message = Messages.Message({
            messageType: Messages.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: "0x0"
        });

        bytes memory messageBytes = messageToBytes(message);

        bytes32 suiSignedMessage = keccak256(
            abi.encodePacked("SUI_NATIVE_BRIDGE", messageBytes)
        );

        bytes[] memory signatures = new bytes[](3);

        // Create signatures from committeeMemberA, committeeMemberB, and committeeMemberC
        signatures[0] = getSignature(suiSignedMessage, committeeMemberPkA);
        signatures[1] = getSignature(suiSignedMessage, committeeMemberPkB);
        signatures[2] = getSignature(suiSignedMessage, committeeMemberPkC);

        // Set the required stake to 500
        uint256 requiredStake = 500;

        // Call the verifyMessageSignatures function and assert that it returns true
        bool result = committee.verifyMessageSignatures(
            signatures,
            messageBytes,
            requiredStake
        );
        assertTrue(result);
    }

    function testVerifyMessageSignaturesWithInvalidSignatures() public {
        // Create a message and hash it
        Messages.Message memory message = Messages.Message({
            messageType: Messages.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: "0x0"
        });

        bytes memory messageBytes = messageToBytes(message);

        bytes32 suiSignedMessage = keccak256(
            abi.encodePacked("SUI_NATIVE_BRIDGE", messageBytes)
        );

        (address eve, uint256 evePk) = makeAddrAndKey("eve");

        bytes[] memory signatures = new bytes[](4);

        // Create signatures from committeeMemberA, committeeMemberB, and committeeMemberC
        signatures[0] = getSignature(suiSignedMessage, committeeMemberPkA);
        signatures[1] = getSignature(suiSignedMessage, committeeMemberPkB);
        signatures[2] = getSignature(suiSignedMessage, committeeMemberPkC);
        signatures[2] = getSignature(suiSignedMessage, evePk); // eve is not a committee member

        // Set the required stake to 500
        uint256 requiredStake = 500;

        // Call the verifyMessageSignatures function and assert that it reverts with "BridgeCommittee: Not a committee member"
        vm.expectRevert("BridgeCommittee: Not a committee member");
        committee.verifyMessageSignatures(
            signatures,
            messageBytes,
            requiredStake
        );
    }

    function testUpdateBlocklistWithSignaturesWithValidSignaturesAndBlocklist()
        public
    {
        // Create a message with blocklist type and payload
        Messages.Message memory message = Messages.Message({
            messageType: Messages.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encodePacked(true, [committeeMemberC]) //FIX: How to encode the blocklist?
        });

        // Encode the message to bytes
        bytes memory messageBytes = messageToBytes(message);

        bytes32 suiSignedMessage = keccak256(
            abi.encodePacked("SUI_NATIVE_BRIDGE", messageBytes)
        );

        // Create signatures from committeeMemberA and committeeMemberB
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(suiSignedMessage, committeeMemberPkA);
        signatures[1] = getSignature(suiSignedMessage, committeeMemberPkB);

        // Call the updateBlocklistWithSignatures function
        committee.updateBlocklistWithSignatures(signatures, messageBytes);

        // Assert that committeeMemberC is blocklisted
        assertEq(committee.blocklist(committeeMemberC), true);

        // Assert that the message nonce is incremented
        assertEq(committee.nonces(Messages.BLOCKLIST), 1);

        // TODO: assert that the event is emitted
    }

    function testUpdateBlocklistWithSignaturesWithValidSignaturesAndUnblocklist()
        public
    {
        // Create a message with blocklist type and payload
        Messages.Message memory message = Messages.Message({
            messageType: Messages.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encodePacked(false, [committeeMemberC]) //FIX: How to encode the blocklist?
        });

        // Encode the message to bytes
        bytes memory messageBytes = messageToBytes(message);

        bytes32 suiSignedMessage = keccak256(
            abi.encodePacked("SUI_NATIVE_BRIDGE", messageBytes)
        );

        // Create signatures from committeeMemberA and committeeMemberB
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(suiSignedMessage, committeeMemberPkA);
        signatures[1] = getSignature(suiSignedMessage, committeeMemberPkB);

        // Call the updateBlocklistWithSignatures function
        committee.updateBlocklistWithSignatures(signatures, messageBytes);

        // Assert that committeeMemberC is unblocklisted
        assertEq(committee.blocklist(committeeMemberC), false);

        // Assert that the message nonce is incremented
        assertEq(committee.nonces(Messages.BLOCKLIST), 1);

        // TODO: assert that the event is emitted
    }

    function testUpdateBlocklistWithSignaturesWithInvalidSignatures() public {
        (address eve, uint256 evePk) = makeAddrAndKey("eve");

        uint8 messageType = Messages.BLOCKLIST;
        uint8 version = 1;
        uint64 nonce = 0;
        uint8 chainId = 1;
        bytes memory payload = abi.encode(bool(true), address(eve)); //FIX: How to encode the blocklist?

        // Encode the message to bytes
        bytes memory messageBytes = abi.encodePacked(
            messageType,
            version,
            nonce,
            chainId,
            payload
        );

        bytes32 suiSignedMessage = keccak256(abi.encodePacked(messageBytes));

        // Create signatures from committeeMemberA and committeeMemberB
        bytes[] memory signatures = new bytes[](3);
        signatures[0] = getSignature(suiSignedMessage, committeeMemberPkA);
        signatures[1] = getSignature(suiSignedMessage, committeeMemberPkB);
        signatures[2] = getSignature(suiSignedMessage, evePk); // eve is not a committee member

        // Call the updateBlocklistWithSignatures function and assert that it reverts with "BridgeCommittee: Invalid signatures"
        vm.expectRevert("BridgeCommittee: Invalid signatures");
        committee.updateBlocklistWithSignatures(signatures, messageBytes);
    }

    function testAddToBlocklist() public {}

    function testRemoveFromBlocklist() public {}

    function testDecodeEmergencyOpPayload() public {
        bytes memory payload0 = abi.encode(uint256(0));
        bytes memory payload1 = abi.encode(uint256(1));

        bool result0 = Messages.decodeEmergencyOpPayload(payload0);
        bool result1 = Messages.decodeEmergencyOpPayload(payload1);

        assertTrue(result0);
        assertFalse(result1);
    }

    function testDecodeEmergencyOpPayloadWithInvalidOpPayload() public {
        bytes memory payload = abi.encode(uint256(2));

        // Call the decodeEmergencyOpPayload function and assert that it reverts with "SuiBridge: Invalid op code"
        vm.expectRevert("SuiBridge: Invalid op code");
        Messages.decodeEmergencyOpPayload(payload);
    }

    function testDecodeUpgradePayload() public {
        // Create some test inputs
        bytes memory payload0 = abi.encode(address(committeeMemberA));
        bytes memory payload1 = abi.encode(address(committeeMemberB));
        bytes memory payload2 = abi.encode(address(committeeMemberC));

        // Call the function with the test inputs
        address result0 = Messages.decodeUpgradePayload(payload0);
        address result1 = Messages.decodeUpgradePayload(payload1);
        address result2 = Messages.decodeUpgradePayload(payload2);

        // Use the assertion functions to check the expected results
        assertEq(result0, address(committeeMemberA));
        assertEq(result1, address(committeeMemberB));
        assertEq(result2, address(committeeMemberC));
    }

    function testFailDecodeUpgradePayload() public {
        // Create an invalid test input
        bytes memory payload = abi.encode(uint256(123));

        // Call the function with the invalid input
        // This should revert because of the abi.decode function
        vm.expectRevert("assertion failed");
        Messages.decodeUpgradePayload(payload);
    }

    function testDecodeBlocklistPayload() public {}

    function testUpgradeCommitteeContract() public {}

    // Helper function to get the signature components from an address
    function getSignature(
        bytes32 digest,
        uint256 privateKey
    ) private view returns (bytes memory) {
        // r and s are the outputs of the ECDSA signature
        // r,s and v are packed into the signature. It should be 65 bytes: 32 + 32 + 1
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // pack v, r, s into 65bytes signature
        // bytes memory signature = abi.encodePacked(r, s, v);
        return abi.encodePacked(r, s, v);
    }

    function messageToBytes(
        Messages.Message memory message
    ) private pure returns (bytes memory) {
        return
            abi.encodePacked(
                "SUI_NATIVE_BRIDGE",
                message.messageType,
                message.version,
                message.nonce,
                message.chainID,
                message.payload
            );
    }
}
