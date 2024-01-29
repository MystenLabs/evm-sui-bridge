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

    function setUp() public {
        bridgeCommittee = new BridgeCommittee();

        (committeeMemeberAddressA, committeeMemeberPkA) = makeAddrAndKey("A");
        (committeeMemeberAddressB, committeeMemeberPkB) = makeAddrAndKey("B");
        (committeeMemeberAddressC, committeeMemeberPkC) = makeAddrAndKey("C");
        (committeeMemeberAddressD, committeeMemeberPkD) = makeAddrAndKey("D");
        (committeeMemeberAddressE, committeeMemeberPkE) = makeAddrAndKey("E");

        address[] memory _committeeMemebers = new address[](5);
        _committeeMemebers[0] = committeeMemeberAddressA;
        _committeeMemebers[1] = committeeMemeberAddressB;
        _committeeMemebers[2] = committeeMemeberAddressC;
        _committeeMemebers[3] = committeeMemeberAddressD;
        _committeeMemebers[4] = committeeMemeberAddressE;

        uint16[] memory _stake = new uint16[](5);
        _stake[0] = committeeMemeberStakeA;
        _stake[1] = committeeMemeberStakeB;
        _stake[2] = committeeMemeberStakeC;
        _stake[3] = committeeMemeberStakeD;
        _stake[4] = committeeMemeberStakeE;

        bridgeCommittee.initialize(_committeeMemebers, _stake);
    }

    function testFuzz_verifyMessageSignatures(
        uint8 messageType,
        bytes memory payload
    ) public view {
        messageType = uint8(bound(messageType, 0, 7));
        // Create a message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        // Create signatures from A - E
        bytes[] memory signatures = new bytes[](5);
        signatures[0] = getSignature(messageHash, committeeMemeberPkA);
        signatures[1] = getSignature(messageHash, committeeMemeberPkB);
        signatures[2] = getSignature(messageHash, committeeMemeberPkC);
        signatures[3] = getSignature(messageHash, committeeMemeberPkD);
        signatures[4] = getSignature(messageHash, committeeMemeberPkE);

        // Call the function to test with the generated parameters
        bridgeCommittee.verifyMessageSignatures(
            signatures,
            message,
            BridgeMessage.TOKEN_TRANSFER
        );
    }

    function testFuzz_updateBlocklistWithSignatures(
        uint8 isBlocklisted
    ) public {
        // Create a blocklist payload
        isBlocklisted = uint8(bound(isBlocklisted, 0, 1));
        address[] memory _blocklist = new address[](5);
        _blocklist[0] == committeeMemeberAddressA;
        _blocklist[1] == committeeMemeberAddressB;
        _blocklist[2] == committeeMemeberAddressC;
        _blocklist[3] == committeeMemeberAddressD;
        _blocklist[4] == committeeMemeberAddressE;

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

        // Create signatures from A - E
        bytes[] memory signatures = new bytes[](5);
        signatures[0] = getSignature(messageHash, committeeMemeberPkA);
        signatures[1] = getSignature(messageHash, committeeMemeberPkB);
        signatures[2] = getSignature(messageHash, committeeMemeberPkC);
        signatures[3] = getSignature(messageHash, committeeMemeberPkD);
        signatures[4] = getSignature(messageHash, committeeMemeberPkE);

        // Call the function to test with the generated parameters
        bridgeCommittee.updateBlocklistWithSignatures(signatures, message);
    }

    // uint16 committeeMemeberStakeA,
    // uint16 committeeMemeberStakeB,
    // uint16 committeeMemeberStakeC,
    // uint16 committeeMemeberStakeD,
    // uint16 committeeMemeberStakeE

    /**
    function testFuzzCommittee(
        address committeeMemeberAddressA,
        address committeeMemeberAddressB,
        address committeeMemeberAddressC,
        address committeeMemeberAddressD,
        address committeeMemeberAddressE
    ) public {
        vm.assume(
            committeeMemeberAddressA != address(0) &&
                committeeMemeberAddressB != address(0) &&
                committeeMemeberAddressC != address(0) &&
                committeeMemeberAddressD != address(0) &&
                committeeMemeberAddressE != address(0)
        );

        vm.assume(
            committeeMemeberAddressA != committeeMemeberAddressB &&
                committeeMemeberAddressA != committeeMemeberAddressC &&
                committeeMemeberAddressA != committeeMemeberAddressD &&
                committeeMemeberAddressA != committeeMemeberAddressE &&
                committeeMemeberAddressB != committeeMemeberAddressC &&
                committeeMemeberAddressB != committeeMemeberAddressD &&
                committeeMemeberAddressB != committeeMemeberAddressE &&
                committeeMemeberAddressC != committeeMemeberAddressD &&
                committeeMemeberAddressC != committeeMemeberAddressE &&
                committeeMemeberAddressD != committeeMemeberAddressE
        );

        address[] memory _committeeMemebers = new address[](3);
        // _committeeMemebers[0] = makeAddr("A");
        // _committeeMemebers[1] = makeAddr("B");
        // _committeeMemebers[2] = makeAddr("C");
        // _committeeMemebers[3] = makeAddr("D");
        // _committeeMemebers[4] = makeAddr("E");
        _committeeMemebers[0] = committeeMemeberAddressA;
        _committeeMemebers[1] = committeeMemeberAddressB;
        _committeeMemebers[2] = committeeMemeberAddressC;
        _committeeMemebers[3] = committeeMemeberAddressD;
        _committeeMemebers[4] = committeeMemeberAddressE;

        // committeeMemeberStakeA = uint16(bound(committeeMemeberStakeA, 100, 4000));
        // committeeMemeberStakeB = uint16(bound(committeeMemeberStakeB, 100, 4000));
        // committeeMemeberStakeC = uint16(bound(committeeMemeberStakeC, 100, 4000));
        // committeeMemeberStakeD = uint16(bound(committeeMemeberStakeD, 100, 4000));
        // committeeMemeberStakeE = uint16(bound(committeeMemeberStakeE, 100, 4000));

        // vm.assume(
        //     committeeMemeberStakeA >= 100 &&
        //         committeeMemeberStakeA <= 5000 &&
        //         committeeMemeberStakeB >= 100 &&
        //         committeeMemeberStakeB <= 5000 &&
        //         committeeMemeberStakeC >= 100 &&
        //         committeeMemeberStakeC <= 5000 &&
        //         committeeMemeberStakeD >= 100 &&
        //         committeeMemeberStakeD <= 5000 &&
        //         committeeMemeberStakeE >= 100 &&
        //         committeeMemeberStakeE <= 5000
        // );

        uint16 committeeMemeberStakeA = 2000;
        uint16 committeeMemeberStakeB = 2000;
        uint16 committeeMemeberStakeC = 2000;
        uint16 committeeMemeberStakeD = 2000;
        uint16 committeeMemeberStakeE = 2000;

        // vm.assume(
        //     committeeMemeberStakeA +
        //         committeeMemeberStakeB +
        //         committeeMemeberStakeC +
        //         committeeMemeberStakeD +
        //         committeeMemeberStakeE ==
        //         10000
        // );

        uint16[] memory _stake = new uint16[](3);
        _stake[0] = committeeMemeberStakeA;
        _stake[1] = committeeMemeberStakeB;
        _stake[2] = committeeMemeberStakeC;
        _stake[3] = committeeMemeberStakeD;
        _stake[4] = committeeMemeberStakeE;

        bridgeCommittee.initialize(_committeeMemebers, _stake);
    }

    */
}
