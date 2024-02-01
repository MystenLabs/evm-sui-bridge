// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";
import "../../contracts/BridgeCommittee.sol";
import "../../contracts/utils/BridgeMessage.sol";

contract BridgeCommitteeFuzzTest is BridgeBaseFuzzTest {
    BridgeCommittee public bridgeCommittee;

    address committeeMemeberAddressA;
    uint256 committeeMemeberPkA;
    address committeeMemeberAddressB;
    uint256 committeeMemeberPkB;
    address committeeMemeberAddressC;
    uint256 committeeMemeberPkC;
    address committeeMemeberAddressD;
    uint256 committeeMemeberPkD;
    address committeeMemeberAddressE;
    uint256 committeeMemeberPkE;

    uint16 private committeeMemeberStakeA = 2000;
    uint16 private committeeMemeberStakeB = 2000;
    uint16 private committeeMemeberStakeC = 2000;
    uint16 private committeeMemeberStakeD = 2000;
    uint16 private committeeMemeberStakeE = 2000;

    address[] _committeeMemebers;
    uint256[] signers = new uint256[](5);

    function setUp() public {
        bridgeCommittee = new BridgeCommittee();

        // (committeeMemeberAddressA, committeeMemeberPkA) = makeAddrAndKey("A");
        // (committeeMemeberAddressB, committeeMemeberPkB) = makeAddrAndKey("B");
        // (committeeMemeberAddressC, committeeMemeberPkC) = makeAddrAndKey("C");
        // (committeeMemeberAddressD, committeeMemeberPkD) = makeAddrAndKey("D");
        // (committeeMemeberAddressE, committeeMemeberPkE) = makeAddrAndKey("E");

        // signers[0] = committeeMemeberPkA;
        // signers[1] = committeeMemeberPkB;
        // signers[2] = committeeMemeberPkC;
        // signers[3] = committeeMemeberPkD;
        // signers[4] = committeeMemeberPkE;

        // _committeeMemebers = new address[](5);
        // _committeeMemebers[0] = committeeMemeberAddressA;
        // _committeeMemebers[1] = committeeMemeberAddressB;
        // _committeeMemebers[2] = committeeMemeberAddressC;
        // _committeeMemebers[3] = committeeMemeberAddressD;
        // _committeeMemebers[4] = committeeMemeberAddressE;

        // uint16[] memory _stake = new uint16[](5);
        // _stake[0] = committeeMemeberStakeA;
        // _stake[1] = committeeMemeberStakeB;
        // _stake[2] = committeeMemeberStakeC;
        // _stake[3] = committeeMemeberStakeD;
        // _stake[4] = committeeMemeberStakeE;

        // bridgeCommittee.initialize(_committeeMemebers, _stake);
    }

    
    function testFuzz_Initialize(
        address[10] memory committeeMembersFuzz,
        uint16[10] memory stakesFuzz
    ) public {

console.log("committeeMembersFuzz: %s", committeeMembersFuzz.length);
        // create the input data
        address[] memory committeeMembers = new address[](10);
        uint16[] memory stakes = new uint16[](10);
        for (uint16 i = 0; i < 10; i++) {
            committeeMembers[i] = committeeMembersFuzz[i];
            stakes[i] = stakesFuzz[i];
        }
console.log("isUnique: %s", isUnique(committeeMembers));
        vm.assume(isUnique(committeeMembers)); // addresses must be unique
        vm.assume(sum(stakes) == 10000); // total stake must be 10000

        // call the function to be tested
        bridgeCommittee.initialize(committeeMembers, stakes);

        // check the postconditions
        // assertEq(bridgeCommittee.totalStake(), 10000); // total stake should be 10000
        for (uint16 i = 0; i < committeeMembersFuzz.length; i++) {
            assertEq(
                bridgeCommittee.committeeMembers(committeeMembersFuzz[i]),
                stakesFuzz[i]
            ); // stakes should be assigned correctly
        }
    }

    function isUnique(address[] memory arr) internal pure returns (bool) {
        for (uint i = 0; i < arr.length; i++) {
            for (uint j = i + 1; j < arr.length; j++) {
                if (arr[i] == arr[j]) {
                    return false;
                }
            }
        }
        return true;
    }

    function sum(uint16[] memory arr) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < arr.length; i++) {
            total += arr[i];
        }
        return total;
    }
    
/**
    function testFuzz_verifyMessageSignatures(
        uint8 messageType,
        bytes memory payload,
        uint8 numSigners
    ) public {
        vm.assume(numSigners > 0 && numSigners <= 5);
        messageType = uint8(bound(messageType, 0, 1));
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: messageType,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                messageType
            )
        {
            // The call was successful
            signaturesValid = true;
        } catch Error(string memory) {
            signaturesValid = false;
        } catch (bytes memory) {
            signaturesValid = false;
        }

        if (signaturesValid) {
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                messageType
            );
        } else {
            // Expect a revert
            vm.expectRevert(
                bytes("BridgeCommittee: Insufficient stake amount")
            );
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                messageType
            );
        }
    }

    function testFuzz_updateBlocklistWithSignatures(
        uint8 isBlocklisted,
        uint8 numSigners,
        uint8 numBlocklistAddresses
    ) public {
        vm.assume(numSigners > 0 && numSigners <= 5);
        vm.assume(numBlocklistAddresses > 0 && numBlocklistAddresses <= 5);

        // Create a blocklist payload
        isBlocklisted = uint8(bound(isBlocklisted, 0, 1));
        address[] memory _blocklist = new address[](numBlocklistAddresses);
        for (uint8 i = 0; i < numBlocklistAddresses; i++) {
            _blocklist[i] = _committeeMemebers[i];
        }

        bytes memory payload = abi.encode(uint8(isBlocklisted), _blocklist);

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

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                BridgeMessage.BLOCKLIST
            )
        {
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
            vm.expectRevert(
                bytes("BridgeCommittee: Insufficient stake amount")
            );
            bridgeCommittee.updateBlocklistWithSignatures(signatures, message);
        }
    }
    */
}
