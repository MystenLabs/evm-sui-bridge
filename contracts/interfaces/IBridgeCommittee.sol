// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/Messages.sol";

interface IBridgeCommittee {
    function verifyMessageSignatures(
        bytes memory signatures,
        bytes memory message,
        uint256 verifyMessageSignatures
    ) external view returns (bool);
}
