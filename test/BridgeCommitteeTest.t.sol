// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";

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

    function testVerifyMessageWithValidSignatures() public {
        // TODO:
        // 1. Create a message
        // 2. Sign the message with enough committee members
        // 3. committee.verifyMessageSignatures(
        //     signatures, message, committee.Message.BLOCKLIST_STAKE_REQUIRED
        // );
    }

    function testVerifyMessageWithInvalidSignatures() public {
        // TODO:
        // 1. Create a message
        // 2. Sign the message with only one committee member
        // 3. committee.verifyMessageSignatures(
        //     signatures, message, committee.Message.BLOCKLIST_STAKE_REQUIRED
        // );
    }
    function testAddToBlocklist() public {}
    function testRemoveFromBlocklist() public {}
    function testDecodeEmergencyOpPayload() public {}
    function testDecodeUpgradePayload() public {}
    function testDecodeBlocklistPayload() public {}
    function testUpgradeCommitteeContract() public {}
}
