// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./utils/BridgeMessage.sol";

contract BridgeCommittee is IBridgeCommittee, UUPSUpgradeable, ContextUpgradeable {
    /* ========== CONSTANTS ========== */

    uint16 public constant BLOCKLIST_STAKE_REQUIRED = 5001;
    uint16 public constant COMMITTEE_UPGRADE_STAKE_REQUIRED = 5001;

    /* ========== STATE VARIABLES ========== */

    // member address => stake amount
    mapping(address => uint16) public committee;
    // member address => is blocklisted
    mapping(address => bool) public blocklist;
    // messageType => nonce
    mapping(uint8 => uint64) public nonces;

    /* ========== INITIALIZER ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    function initialize(address[] memory _committee, uint16[] memory stakes) external initializer {
        __UUPSUpgradeable_init();
        uint16 total_stake = 0;

        require(
            _committee.length == stakes.length,
            "BridgeCommittee: Committee and stake arrays must be of the same length"
        );

        for (uint16 i = 0; i < _committee.length; i++) {
            require(committee[_committee[i]] == 0, "BridgeCommittee: Duplicate committee member");
            committee[_committee[i]] = stakes[i];
            total_stake += stakes[i];
        }

        require(total_stake == 10000, "BridgeCommittee: Total stake must be 10000");
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function updateBlocklistWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external {
        // verify message type nonce
        require(message.nonce == nonces[message.messageType], "BridgeCommittee: Invalid nonce");

        // verify message type
        require(
            message.messageType == BridgeMessage.BLOCKLIST,
            "BridgeCommittee: message does not match type"
        );

        // compute message hash
        bytes32 messageHash = BridgeMessage.getMessageHash(message);

        // verify signatures
        require(
            verifyMessageSignatures(signatures, messageHash, BLOCKLIST_STAKE_REQUIRED),
            "BridgeCommittee: Invalid signatures"
        );

        // decode the blocklist payload
        (bool isBlocklisted, address[] memory _blocklist) = decodeBlocklistPayload(message.payload);

        // update the blocklist
        _updateBlocklist(_blocklist, isBlocklisted);

        // increment message type nonce
        nonces[BridgeMessage.BLOCKLIST]++;
    }

    function upgradeCommitteeWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external {
        // verify message type
        require(
            message.messageType == BridgeMessage.COMMITTEE_UPGRADE,
            "BridgeCommittee: message does not match type"
        );

        // verify message type nonce
        require(message.nonce == nonces[message.messageType], "BridgeCommittee: Invalid nonce");

        // compute message hash
        bytes32 messageHash = BridgeMessage.getMessageHash(message);

        // verify signatures
        require(
            verifyMessageSignatures(signatures, messageHash, COMMITTEE_UPGRADE_STAKE_REQUIRED),
            "BridgeCommittee: Invalid signatures"
        );

        // decode the upgrade payload
        (address implementationAddress, bytes memory callData) =
            BridgeMessage.decodeUpgradePayload(message.payload);

        // update the upgrade
        _upgradeCommittee(implementationAddress, callData);

        // increment message type nonce
        nonces[BridgeMessage.COMMITTEE_UPGRADE]++;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function verifyMessageSignatures(
        bytes[] memory signatures,
        bytes32 messageHash,
        uint32 requiredStake
    ) public view override returns (bool) {
        // TODO: check for duplicate signatures

        // Loop over the signatures and check if they are valid
        uint16 approvalStake;
        address signer;
        for (uint16 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            // Extract R, S, and V components from the signature
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

            // Recover the signer address
            signer = ecrecover(messageHash, v, r, s);

            // Check if the signer is a committee member and not already approved
            require(committee[signer] > 0, "BridgeCommittee: Not a committee member");

            // If signer is block listed skip this signature
            if (blocklist[signer]) continue;

            approvalStake += committee[signer];
        }

        return approvalStake >= requiredStake;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _updateBlocklist(address[] memory _blocklist, bool isBlocklisted) internal {
        // check original blocklist value of each validator
        for (uint16 i = 0; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = isBlocklisted;
        }

        emit BlocklistUpdated(_blocklist, isBlocklisted);
    }

    function decodeBlocklistPayload(bytes memory payload)
        public
        pure
        returns (bool, address[] memory)
    {
        (uint8 blocklistType, address[] memory validators) = abi.decode(payload, (uint8, address[]));
        // blocklistType: 0 = blocklist, 1 = unblocklist
        bool blocklisted = (blocklistType == 0) ? true : false;
        return (blocklisted, validators);
    }

    function _upgradeCommittee(address newImplementation, bytes memory data) internal {
        if (data.length > 0) _upgradeToAndCallUUPS(newImplementation, data, true);
        else _upgradeTo(newImplementation);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        require(_msgSender() == address(this));
    }

    // Helper function to split a signature into R, S, and V components
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "BridgeCommittee: Invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }
    }

    /* ========== EVENTS ========== */

    event MessageProcessed(bytes message);
}
