// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./utils/CommitteeOwned.sol";

/// @title BridgeCommittee
/// @dev A contract that manages a bridge committee for a bridge between two blockchains. The committee is responsible for approving and processing messages related to the bridge operations.
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

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
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

    /// @dev Verifies the signatures of the given messages.
    /// @param signatures The array of signatures to be verified.
    /// @param message The message to be verified.
    /// @param messageType The type of the message.
    function verifyMessageSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message,
        uint8 messageType
    ) public view override {
        // TODO: check for duplicate signatures

        require(message.messageType == messageType, "BridgeCommittee: message does not match type");

        uint32 requiredStake = BridgeMessage.getRequiredStake(message);

        // Loop over the signatures and check if they are valid
        uint16 approvalStake;
        address signer;
        for (uint16 i = 0; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            // recover the signer from the signature
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

            (signer,) = ECDSA.tryRecover(BridgeMessage.computeHash(message), v, r, s);

            // Check if the signer is a committee member and not already approved
            require(committeeMembers[signer] > 0, "BridgeCommittee: Not a committee member");

            // If signer is block listed skip this signature
            if (blocklist[signer]) continue;

            approvalStake += committeeMembers[signer];
        }

        require(approvalStake >= requiredStake, "BridgeCommittee: Insufficient stake amount");
    }

    /// @dev Updates the blocklist with the provided signatures and message.
    /// @param signatures The array of signatures for the message.
    /// @param message The BridgeMessage containing the blocklist payload.
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

    /// @dev Upgrades the committee with the provided signatures and message.
    /// @param signatures The array of signatures from committee members.
    /// @param message The BridgeMessage containing the upgrade payload.
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

    /// @dev Internal function to update the blocklist status of multiple addresses.
    /// @param _blocklist The array of addresses to update the blocklist status for.
    /// @param isBlocklisted The new blocklist status to set for the addresses.
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

    // Helper function to split a signature into R, S, and V components
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "BridgeCommittee: Invalid signature length");
        // ecrecover takes the signature parameters, and the only way to get them
        // currently is to use assembly.
        /// @solidity memory-safe-assembly
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        //adjust for ethereum signature verification
        if (v < 27) v += 27;
    }

    /// @dev Internal function to authorize an upgrade to a new implementation contract. Only the contract itself can authorize an upgrade.
    /// @param newImplementation The address of the new implementation contract.
    function _authorizeUpgrade(address newImplementation) internal view override {
        require(msg.sender == address(this));
    }
}
