// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeCommittee {
    function verifyMessageSignatures(
        bytes[] memory signatures,
        bytes32 messageHash,
        uint32 requiredStake
    ) external view returns (bool);

    event BlocklistUpdated(address[] newMembers, bool isBlocklisted);
}
