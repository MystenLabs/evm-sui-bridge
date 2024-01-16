// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IBridgeCommittee
/// @dev Interface for the Bridge Committee contract.
interface IBridgeCommittee {

    /// @dev Verifies the signatures of the given messages.
    /// @param signatures The array of signatures to be verified.
    /// @param messageHash The hash of the message to be verified.
    /// @param requiredStake The required stake for the verification.
    /// @return A boolean indicating whether the signatures are valid.
    function verifyMessageSignatures(
        bytes[] memory signatures,
        bytes32 messageHash,
        uint32 requiredStake
    ) external view returns (bool);

    /// @dev Emitted when the blocklist is updated.
    /// @param newMembers The array of new committee members.
    /// @param isBlocklisted A boolean indicating whether the members are blocklisted.
    event BlocklistUpdated(address[] newMembers, bool isBlocklisted);
}
