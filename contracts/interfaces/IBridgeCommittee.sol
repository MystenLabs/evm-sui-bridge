// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/BridgeMessage.sol";

interface IBridgeCommittee {
    /// @dev Verifies the signatures of the given messages.
    /// @param signatures The array of signatures to be verified.
    /// @param message The message to be verified.
    function verifySignatures(bytes[] memory signatures, BridgeMessage.Message memory message)
        external
        view;

    function chainID() external view returns (uint8);

    /* ========== EVENTS ========== */

    /// @dev Emitted when the blocklist is updated.
    /// @param newMembers The addresses of the new committee members.
    /// @param isBlocklisted A boolean indicating whether the committee members are blocklisted or not.
    event BlocklistUpdated(address[] newMembers, bool isBlocklisted);

    /// @dev Emitted when a message is processed by the bridge committee.
    /// @param message The processed message.
    event MessageProcessed(bytes message);
}
