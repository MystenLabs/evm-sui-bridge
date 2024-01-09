// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";
import "../contracts/utils/BridgeMessage.sol";

contract BridgeCommitteeTest is BridgeBaseTest {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testBridgeCommitteeInitialization() public {
        assertEq(committee.committee(committeeMemberA), 1000);
        assertEq(committee.committee(committeeMemberB), 1000);
        assertEq(committee.committee(committeeMemberC), 1000);
        assertEq(committee.committee(committeeMemberD), 2002);
        assertEq(committee.committee(committeeMemberE), 4998);
    }

    function testVerifyMessageSignaturesWithValidSignatures() public {
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: "0x0"
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);

        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](3);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);

        // Set the required stake to 500
        uint16 requiredStake = 500;

        // Call the verifyMessageSignatures function and assert that it returns true
        bool result = committee.verifyMessageSignatures(signatures, messageHash, requiredStake);
        assertTrue(result);
    }

    function testVerifyMessageSignaturesWithInvalidSignatures() public {
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: "0x0"
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);

        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](3);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);

        // Set the required stake to 5000
        uint16 requiredStake = 5000;

        // Call the verifyMessageSignatures function and assert that it returns true
        bool result = committee.verifyMessageSignatures(signatures, messageHash, requiredStake);
        assertFalse(result);
    }
    // TODO: extract invariant tests to a separate file
    // function invariant_testVerifyMessageSignaturesWithValidSignatures(
    //     uint8 _version,
    //     uint64 _nonce,
    //     uint8 _chainID,
    //     bytes memory _payload
    // ) public {
    //     // Generate a random message
    //     BridgeMessage.Message memory message = BridgeMessage.Message({
    //         messageType: BridgeMessage.TOKEN_TRANSFER,
    //         version: _version,
    //         nonce: _nonce,
    //         chainID: _chainID,
    //         payload: _payload
    //     });

    //     bytes memory messageBytes = encodeMessage(message);

    //     bytes32 messageHash = keccak256(messageBytes);

    //     bytes[] memory signatures = new bytes[](3);

    //     // Generate random signatures from committee members
    //     signatures[0] = getSignature(messageHash, committeeMemberPkA);
    //     signatures[1] = getSignature(messageHash, committeeMemberPkB);
    //     signatures[2] = getSignature(messageHash, committeeMemberPkC);

    //     uint16 requiredStake = 500;

    //     // Check if the signatures are valid
    //     assertTrue(
    //         committee.verifyMessageSignatures(
    //             signatures,
    //             messageHash,
    //             requiredStake
    //         )
    //     );
    // }

    function testDecodeBlocklistPayload() public {
        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(0), _blocklist);

        // decode the payload
        (bool blocklisted, address[] memory validators) = committee.decodeBlocklistPayload(payload);

        // assert that the blocklist contains the correct address
        assertEq(validators[0], committeeMemberA);
        assertTrue(blocklisted);
    }

    // function invariant_testDecodeBlocklistPayload(address committeeMember) public {
    //     // create payload
    //     address[] memory _blocklist = new address[](1);
    //     _blocklist[0] = committeeMember;
    //     bytes memory payload = abi.encode(uint8(0), _blocklist);

    //     // decode the payload
    //     (bool blocklisted, address[] memory validators) = committee.decodeBlocklistPayload(payload);

    //     // assert that the blocklist contains the correct address
    //     assertEq(validators[0], committeeMember);
    //     assertTrue(blocklisted);
    // }

    function testAddToBlocklist() public {
        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(0), _blocklist);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from A - D
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        // Set the required stake to 5000
        uint16 requiredStake = 5000;

        // verify CommitteeMemberA's signature is still valid
        bool result = committee.verifyMessageSignatures(signatures, messageHash, requiredStake);
        assertTrue(result);

        committee.updateBlocklistWithSignatures(signatures, message);

        // verify CommitteeMemberA's signature is no longer valid
        result = committee.verifyMessageSignatures(signatures, messageHash, requiredStake);
        assertFalse(result);
        assertTrue(committee.blocklist(committeeMemberA));
    }

    // function invariant_testAddToBlocklist(
    //     address committeeMember,
    //     uint8 _version,
    //     uint64 _nonce,
    //     uint8 _chainID
    // ) public {
    //     // create payload
    //     address[] memory _blocklist = new address[](1);
    //     _blocklist[0] = committeeMember;
    //     bytes memory payload = abi.encode(uint8(0), _blocklist);

    //     // Create a message
    //     BridgeMessage.Message memory message = BridgeMessage.Message({
    //         messageType: BridgeMessage.BLOCKLIST,
    //         version: _version,
    //         nonce: _nonce,
    //         chainID: _chainID,
    //         payload: payload
    //     });

    //     bytes memory messageBytes = encodeMessage(message);
    //     bytes32 messageHash = keccak256(messageBytes);
    //     bytes[] memory signatures = new bytes[](4);

    //     // Create signatures from A - D
    //     signatures[0] = getSignature(messageHash, committeeMemberPkA);
    //     signatures[1] = getSignature(messageHash, committeeMemberPkB);
    //     signatures[2] = getSignature(messageHash, committeeMemberPkC);
    //     signatures[3] = getSignature(messageHash, committeeMemberPkD);

    //     // Set the required stake to 5000
    //     uint16 requiredStake = 5000;

    //     // verify CommitteeMember's signature is still valid
    //     bool result = committee.verifyMessageSignatures(
    //         signatures,
    //         messageHash,
    //         requiredStake
    //     );
    //     assertTrue(result);

    //     committee.updateBlocklistWithSignatures(signatures, message);

    //     // verify CommitteeMember's signature is no longer valid
    //     result = committee.verifyMessageSignatures(
    //         signatures,
    //         messageHash,
    //         requiredStake
    //     );
    //     assertFalse(result);
    //     assertTrue(committee.blocklist(committeeMember));
    // }

    function testRemoveFromBlocklist() public {
        testAddToBlocklist();

        // create payload
        address[] memory _blocklist = new address[](1);
        _blocklist[0] = committeeMemberA;
        bytes memory payload = abi.encode(uint8(1), _blocklist);

        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BLOCKLIST,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);
        bytes[] memory signatures = new bytes[](4);

        // Create signatures from B - E
        signatures[0] = getSignature(messageHash, committeeMemberPkB);
        signatures[1] = getSignature(messageHash, committeeMemberPkC);
        signatures[2] = getSignature(messageHash, committeeMemberPkD);
        signatures[3] = getSignature(messageHash, committeeMemberPkE);

        committee.updateBlocklistWithSignatures(signatures, message);

        // verify CommitteeMemberA is no longer blocklisted
        assertFalse(committee.blocklist(committeeMemberA));
    }

    // TODO
    function testDecodeUpgradePayload() public {}
    function testUpgradeCommitteeContract() public {}
}
