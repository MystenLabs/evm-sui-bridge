// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./utils/CommitteeOwned.sol";

contract BridgeCommittee is
    IBridgeCommittee,
    CommitteeOwned,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    /* ========== STATE VARIABLES ========== */

    // member address => stake amount
    mapping(address => uint16) public committeeMembers;
    // member address => is blocklisted
    mapping(address => bool) public blocklist;

    /* ========== INITIALIZER ========== */

    function initialize(address[] memory _committeeMembers, uint16[] memory stakes)
        external
        initializer
    {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __CommitteeOwned_init(address(this));
        require(
            _committeeMembers.length == stakes.length,
            "BridgeCommittee: Committee and stake arrays must be of the same length"
        );

        uint16 total_stake = 0;
        for (uint16 i = 0; i < _committeeMembers.length; i++) {
            require(
                committeeMembers[_committeeMembers[i]] == 0,
                "BridgeCommittee: Duplicate committee member"
            );
            committeeMembers[_committeeMembers[i]] = stakes[i];
            total_stake += stakes[i];
        }

        require(total_stake == 10000, "BridgeCommittee: Total stake must be 10000");
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function verifyMessageSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message,
        uint8 messageType
    ) public view override {
        // TODO: check for duplicate signatures

        require(message.messageType == messageType, "SuiBridge: message does not match type");

        uint32 requiredStake = BridgeMessage.getRequiredStake(message);

        // Loop over the signatures and check if they are valid
        uint16 approvalStake;
        address signer;
        for (uint16 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            // recover the signer from the signature
            (signer,) = ECDSA.tryRecover(BridgeMessage.computeHash(message), signature);

            // Check if the signer is a committee member and not already approved
            require(committeeMembers[signer] > 0, "BridgeCommittee: Not a committee member");

            // If signer is block listed skip this signature
            if (blocklist[signer]) continue;

            approvalStake += committeeMembers[signer];
        }

        require(approvalStake >= requiredStake, "BridgeCommittee: Insufficient stake amount");
    }

    function updateBlocklistWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        nonceInOrder(message)
        validateMessage(message, signatures, BridgeMessage.BLOCKLIST)
    {
        // decode the blocklist payload
        (bool isBlocklisted, address[] memory _blocklist) =
            BridgeMessage.decodeBlocklistPayload(message.payload);

        // update the blocklist
        _updateBlocklist(_blocklist, isBlocklisted);
    }

    function upgradeCommitteeWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        nonceInOrder(message)
        validateMessage(message, signatures, BridgeMessage.COMMITTEE_UPGRADE)
    {
        // decode the upgrade payload
        (address implementationAddress, bytes memory callData) =
            BridgeMessage.decodeUpgradePayload(message.payload);

        // update the upgrade
        _upgradeCommittee(implementationAddress, callData);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _updateBlocklist(address[] memory _blocklist, bool isBlocklisted) internal {
        // check original blocklist value of each validator
        for (uint16 i = 0; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = isBlocklisted;
        }

        emit BlocklistUpdated(_blocklist, isBlocklisted);
    }

    function _upgradeCommittee(address newImplementation, bytes memory data) internal {
        if (data.length > 0) _upgradeToAndCallUUPS(newImplementation, data, true);
        else _upgradeTo(newImplementation);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        require(msg.sender == address(this));
    }
}
