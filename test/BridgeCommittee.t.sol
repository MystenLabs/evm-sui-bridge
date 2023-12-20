// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/BridgeCommittee.sol";
import "../contracts/BridgeVault.sol";
import "../contracts/SuiBridge.sol";

contract AccessManagerTest is Test {
    address committeeMemberA;
    address committeeMemberB;
    address committeeMemberC;
    address deployer;

    BridgeCommittee public committee;
    SuiBridge public bridge;
    BridgeVault public vault;

    // This funciton is called before each unit test
    function setUp() public {
        // TODO: setup tests
        committeeMemberA = makeAddr("a");
        committeeMemberB = makeAddr("b");
        committeeMemberC = makeAddr("c");
        vm.deal(committeeMemberA, 100 ether);
        vm.deal(committeeMemberB, 100 ether);
        vm.deal(committeeMemberC, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        // TODO: initialize this with mock tokens
        address[] memory _supportedTokens = new address[](1);
        bridge = new SuiBridge();
        bridge.initialize(_supportedTokens);
        vault = new BridgeVault(address(bridge));
        address[] memory _committee = new address[](3);
        uint256[] memory _stake = new uint256[](3);
        _committee[0] = committeeMemberA;
        _committee[1] = committeeMemberB;
        _committee[2] = committeeMemberC;
        _stake[0] = 1000;
        _stake[1] = 1000;
        _stake[2] = 1000;
        committee = new BridgeCommittee(_committee, _stake, address(bridge));
    }

    function testBridgeCommitteeInitialization() public {
        assertEq(committee.committee(committeeMemberA), 1000);
        assertEq(committee.committee(committeeMemberB), 1000);
        assertEq(committee.committee(committeeMemberC), 1000);
        assertEq(committee.totalCommitteeStake(), 3000);
        assertEq(committee.nonce(), 1);
        assertEq(committee.bridge(), address(bridge));
    }

    function testGetAddressFromPayload() public {
        bytes memory payload = abi.encodePacked(committeeMemberA);
        assertEq(committee.getAddressFromPayload(payload), committeeMemberA);

        payload = abi.encodePacked(committeeMemberB);
        assertEq(committee.getAddressFromPayload(payload), committeeMemberB);

        payload = abi.encodePacked(committeeMemberC);
        assertEq(committee.getAddressFromPayload(payload), committeeMemberC);

        payload = abi.encodePacked(address(0));
        assertEq(committee.getAddressFromPayload(payload), address(0));
    }

    function testGetAddressFromPayloadWithEmptyPayload() public {
        // Prepare an empty payload
        bytes memory payload = "";

        // Call the function and expect it to revert with a message
        vm.expectRevert("Empty payload");
        committee.getAddressFromPayload(payload);
    }

    /**
    function testGetAddressesFromPayload() public {
        // Prepare a payload with addresseses
        address[] memory expected = new address[](3);
        expected[0] = committeeMemberA;
        expected[1] = committeeMemberB; 
        expected[2] = committeeMemberC;
        bytes memory payload = abi.encodePacked(expected);

        // Call the function and get the result
        address[] memory actual = committee.getAddressesFromPayload(payload);

        // Assert that the result matches the expected array
        assertEq(actual, expected);
    }
    */

    function testGetAddressesFromPayloadWithEmptyPayload() public {
        // Prepare an empty payload
        bytes memory payload = "";

        // Call the function and expect it to revert with a message
        vm.expectRevert("Empty payload");
        committee.getAddressesFromPayload(payload);
    }

    function testConstructMessage() public {
        uint256 expectedNonce = 1;
        uint256 expectedVersion = 1;
        BridgeCommittee.MessageType expectedType = BridgeCommittee
            .MessageType
            .BRIDGE_MESSAGE;
        bytes memory expectedPayload = "0x1234";

        bytes memory message = abi.encodePacked(
            expectedNonce,
            expectedVersion,
            expectedType,
            expectedPayload
        );

        // Call the function and get the result
        BridgeCommittee.Message memory actual = committee.constructMessage(
            message
        );

        // Assert that the result matches the expected components
        assertEq(actual.nonce, expectedNonce);
        assertEq(actual.version, expectedVersion);
        assertEq(actual.messageType, expectedType);
        assertEq(actual.payload, expectedPayload);
    }

    function testConstructMessageWithEmptyMessage() public {
        // Prepare an empty message
        bytes memory message = "";

        // Call the function and expect it to revert with a message
        vm.expectRevert("Empty message");
        committee.constructMessage(message);
    }
}
