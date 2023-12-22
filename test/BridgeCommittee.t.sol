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
        assertEq(committee.committee(committeeMemberD), 1000);
        // TODO: test rest of committee state initialization
    }

    // TESTS:
    // - submitMessageWithSignatures with invalid signatures
    // - submitMessageWithSignatures with invalid message
    // - submitMessageWithBlocklistSigners
    // - testProcessBlocklistAdditionMessage
    // - testProcessBlocklistRemovalMessage
    // - testProcessBridgeOwnershipMessage
    // - testBlocklistMessageApproval
    // - testBridgeOwnershipMessageApproval
    // - testBridgeUpgradeMessageApproval
    // - testOpCodeMessageApproval
    // - testDecodeMessageType
    // - testDecodeEmergencyOpMessageType
    // - testDecodeBridgeOwnershipMessageType
    // - testDecodeBridgeUpgradeMessageType
    // - testDecodeBlocklistMessageType
}
