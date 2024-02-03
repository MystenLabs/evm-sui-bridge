// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import "./mocks/MockSuiBridgeV2.sol";
import "../contracts/BridgeCommittee.sol";
import "../contracts/SuiBridge.sol";
import "./BridgeBaseTest.t.sol";
import "forge-std/Test.sol";

contract CommitteeUpgradeableTest is BridgeBaseTest {
    MockSuiBridgeV2 bridgeV2;

    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
        address[] memory _committeeMembers = new address[](5);
        uint16[] memory _stake = new uint16[](5);
        _committeeMembers[0] = committeeMemberA;
        _committeeMembers[1] = committeeMemberB;
        _committeeMembers[2] = committeeMemberC;
        _committeeMembers[3] = committeeMemberD;
        _committeeMembers[4] = committeeMemberE;
        _stake[0] = 1000;
        _stake[1] = 1000;
        _stake[2] = 1000;
        _stake[3] = 2002;
        _stake[4] = 4998;

        // deploy bridge committee
        address _committee = Upgrades.deployUUPSProxy(
            "BridgeCommittee.sol",
            abi.encodeCall(BridgeCommittee.initialize, (_committeeMembers, _stake))
        );

        committee = BridgeCommittee(_committee);

        // deploy sui bridge
        address _bridge = Upgrades.deployUUPSProxy(
            "SuiBridge.sol",
            abi.encodeCall(
                SuiBridge.initialize,
                (_committee, address(0), address(0), address(0), address(0), 99)
            )
        );

        bridge = SuiBridge(_bridge);
        bridgeV2 = new MockSuiBridgeV2();
    }

    function testUpgradeWithSignaturesSuccess() public {
        bytes memory initializer = abi.encodeCall(MockSuiBridgeV2.initializeV2, ());
        bytes memory payload = abi.encode(address(bridge), address(bridgeV2), initializer);

        // Create upgrade message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPGRADE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        assertFalse(bridge.paused());
        bridge.upgradeWithSignatures(signatures, message);
        assertTrue(bridge.paused());
        assertEq(Upgrades.getImplementationAddress(address(bridge)), address(bridgeV2));
    }

    function testUpgradeWithSignaturesInsufficientStakeAmount() public {
        // Create message
        bytes memory initializer = abi.encodeCall(MockSuiBridgeV2.initializeV2, ());
        bytes memory payload = abi.encode(address(bridge), address(bridgeV2), initializer);

        // Create upgrade message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPGRADE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        bridge.upgradeWithSignatures(signatures, message);
    }

    function testUpgradeWithSignaturesMessageDoesNotMatchType() public {
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(0)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("BridgeCommittee: message does not match type"));
        bridge.upgradeWithSignatures(signatures, message);
    }

    function testUpgradeWithSignaturesInvalidNonce() public {
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPGRADE,
            version: 1,
            nonce: 10,
            chainID: 1,
            payload: abi.encode(0)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("MessageVerifier: Invalid nonce"));
        bridge.upgradeWithSignatures(signatures, message);
    }

    function testUpgradeWithSignaturesERC1967UpgradeNewImplementationIsNotUUPS() public {
        bytes memory initializer = abi.encodeCall(MockSuiBridgeV2.initializeV2, ());
        bytes memory payload = abi.encode(address(bridge), address(this), initializer);

        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPGRADE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        assertFalse(bridge.paused());
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1967Utils.ERC1967InvalidImplementation.selector, address(this)
            )
        );
        bridge.upgradeWithSignatures(signatures, message);
    }

    function testUpgradeWithSignaturesInvalidProxyAddress() public {
        bytes memory initializer = abi.encodeCall(MockSuiBridgeV2.initializeV2, ());
        bytes memory payload = abi.encode(address(this), address(bridgeV2), initializer);

        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPGRADE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("SuiBridge: Invalid proxy address"));
        bridge.upgradeWithSignatures(signatures, message);
    }

    // TODO: addMockUpgradeTest using OZ upgrades package to show upgrade safety checks
}
