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

    // TESTS:
    // TODO: https://medium.com/@pbharrin/how-to-sign-messages-in-solidity-71ad98f5aad0

    function testVerifyMessageSignaturesWithValidSignatures() public {
        // 1. Create a message and hash it
        Messages.Message memory message = Messages.Message({
            messageType: Messages.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: "0x0"
        });

        bytes memory messageBytes = messageToBytes(message);

        bytes32 suiSignedMessageHash = keccak256(
            abi.encodePacked("SUI_NATIVE_BRIDGE", messageBytes)
        );

        // Create signatures from alice, bob, and charlie
        bytes memory signatures = new bytes;
        signatures[0] = getSignature(suiSignedMessageHash, committeeMemberPkA);
        signatures[1] = getSignature(suiSignedMessageHash, committeeMemberPkB);
        signatures[2] = getSignature(suiSignedMessageHash, committeeMemberPkC);
        // (signatures[0], signatures[1], signatures[2:63]) = getSignature(suiSignedMessageHash, committeeMemberPkA);
        // (signatures[64], signatures[65], signatures[66:127]) = getSignature(suiSignedMessageHash, committeeMemberPkB);
        // (signatures[128], signatures[129], signatures[130]) = getSignature(suiSignedMessageHash, committeeMemberPkC);

        // Set the required stake to 500
        uint256 requiredStake = 500;

        // Call the verifyMessageSignatures function and assert that it returns true
        bool result = committee.verifyMessageSignatures(
            signatures,
            messageBytes,
            requiredStake
        );
        assertEq(result, true);
    }

    // function testVerifyMessageWithInvalidSignatures() public {
    //     // 1. Create a message and hash it
    //     Messages.Message memory message = Messages.Message({
    //         messageType: Messages.TOKEN_TRANSFER,
    //         version: 1,
    //         nonce: 1,
    //         chainID: 1,
    //         payload: "0x0"
    //     });
    //     bytes32 msgHash = keccak256(
    //         abi.encodePacked("SUI_NATIVE_BRIDGE", message)
    //     );

    //     // 2. Create signatures from committeeMemberA, committeeMemberB, committeeMemberC, and committeeMemberD
    //     bytes memory signatures = new bytes(192);
    //     (signatures[0], signatures[1], signatures[2]) = getSignature(
    //         msgHash,
    //         committeeMemberA
    //     );
    //     (signatures[64], signatures[65], signatures[66]) = getSignature(
    //         msgHash,
    //         committeeMemberB
    //     );
    //     (signatures[128], signatures[129], signatures[130]) = getSignature(
    //         msgHash,
    //         committeeMemberC
    //     );
    //     (signatures[192], signatures[193], signatures[194]) = getSignature(
    //         msgHash,
    //         committeeMemberD
    //     );

    //     // 3. Set the required stake to 500
    //     uint256 requiredStake = 500;

    //     // 4. Call the verifyMessageSignatures function and assert that it returns true
    //     bool result = committee.verifyMessageSignatures(
    //         signatures,
    //         message,
    //         requiredStake
    //     );
    //     assertEq(result, true);
    // }

    function testAddToBlocklist() public {}

    function testRemoveFromBlocklist() public {}

    function testDecodeEmergencyOpPayload() public {}

    function testDecodeUpgradePayload() public {}

    function testDecodeBlocklistPayload() public {}

    function testUpgradeCommitteeContract() public {}

    // function testVerifyMessageSignaturesWithValidSignatures() public {}

    // function testVerifyMessageSignaturesWithInvalidSignatures() public {
    //     // Create a message and hash it
    //     bytes memory message = "Hello, world!";
    //     bytes32 suiSignedMessageHash = keccak256(
    //         abi.encodePacked("SUI_NATIVE_BRIDGE", message)
    //     );

    //     // Create signatures from alice, bob, and dave
    //     bytes memory signatures = new bytes(192);
    //     (signatures[0], signatures[1], signatures[2]) = getSignature(
    //         suiSignedMessageHash,
    //         alice
    //     );
    //     (signatures[64], signatures[65], signatures[66]) = getSignature(
    //         suiSignedMessageHash,
    //         bob
    //     );
    //     (signatures[128], signatures[129], signatures[130]) = getSignature(
    //         suiSignedMessageHash,
    //         dave
    //     );

    //     // Set the required stake to 500
    //     uint256 requiredStake = 500;

    //     // Call the verifyMessageSignatures function and assert that it returns false
    //     bool result = committee.verifyMessageSignatures(
    //         signatures,
    //         message,
    //         requiredStake
    //     );
    //     assertEq(result, false);
    // }

    // function testVerifyMessageSignaturesWithRevert() public {
    //     // Create a message and hash it
    //     bytes memory message = "Hello, world!";
    //     bytes32 suiSignedMessageHash = keccak256(
    //         abi.encodePacked("SUI_NATIVE_BRIDGE", message)
    //     );

    //     // Create signatures from alice, bob, and charlie
    //     bytes memory signatures = new bytes(192);
    //     (signatures[0], signatures[1], signatures[2]) = getSignature(
    //         suiSignedMessageHash,
    //         alice
    //     );
    //     (signatures[64], signatures[65], signatures[66]) = getSignature(
    //         suiSignedMessageHash,
    //         bob
    //     );
    //     (signatures[128], signatures[129], signatures[130]) = getSignature(
    //         suiSignedMessageHash,
    //         charlie
    //     );

    //     // Set the required stake to 1000
    //     uint256 requiredStake = 1000;

    //     // Call the verifyMessageSignatures function and assert that it reverts with "BridgeCommittee: Not enough stake"
    //     vm.expectRevert("BridgeCommittee: Not enough stake");
    //     committee.verifyMessageSignatures(signatures, message, requiredStake);
    // }

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
