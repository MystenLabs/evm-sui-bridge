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
        // TODO: test rest of committee state initialization
    }

    // TESTS:
    // - testVerifyMessageWithValidSignatures
    // - testVerifyMessageWithInvalidSignatures
    // - testAddToBlocklist
    // - testRemoveFromBlocklist
    // - testVerifyMessageApprovalStake
    // - testDecodeEmergencyOpPayload
    // - testDecodeUpgradePayload
    // - testDecodeBlocklistPayload
    // - testUpgradeCommitteeContract
}
