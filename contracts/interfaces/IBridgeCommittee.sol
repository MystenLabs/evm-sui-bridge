// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../utils/BridgeMessage.sol";

interface IBridgeCommittee {
    function verifyMessageSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message,
        uint8 messageType
    ) external;

    /* ========== EVENTS ========== */
    event BlocklistUpdated(address[] newMembers, bool isBlocklisted);
    event MessageProcessed(bytes message);
}
