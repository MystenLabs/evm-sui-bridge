// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./utils/CommitteeUpgradeable.sol";

/// @title BridgeCommittee
/// @notice This contract manages the committee members of the SuiBridge. The committee members are
/// responsible for signing messages used to update various bridge state including the committee itself.
/// The contract also provides functions to manage a blocklist of committee members that are unable to
/// sign valid messages.
contract BridgeCommittee is IBridgeCommittee, CommitteeUpgradeable {
    /* ========== STATE VARIABLES ========== */

    uint8 public chainID;
    mapping(address committeeMember => uint16 stakeAmount) public committeeStake;
    mapping(address committeeMember => uint8 index) public committeeIndex;
    mapping(address committeeMember => bool isBlocklisted) public blocklist;

    /* ========== INITIALIZER ========== */

    /// @notice Initializes the contract with the provided parameters.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    /// the provided arrays must have the same length and the total stake provided must equal 10000.
    /// @param _committee addresses of the committee members.
    /// @param stake amounts of the committee members.
    /// @param _chainID used to identify the chain when validating messages.
    function initialize(address[] memory _committee, uint16[] memory stake, uint8 _chainID)
        external
        initializer
    {
        __CommitteeUpgradeable_init(address(this));
        __UUPSUpgradeable_init();
        require(
            _committee.length == stake.length,
            "BridgeCommittee: Committee and stake arrays must be of the same length"
        );

        uint16 total_stake;
        for (uint16 i; i < _committee.length; i++) {
            require(
                committeeStake[_committee[i]] == 0, "BridgeCommittee: Duplicate committee member"
            );
            committeeStake[_committee[i]] = stake[i];
            committeeIndex[_committee[i]] = uint8(i);
            total_stake += stake[i];
        }

        require(total_stake == 10000, "BridgeCommittee: Total stake must be 10000"); // 10000 == 100%
        chainID = _chainID;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @notice Verifies the provided signatures for the given message by aggregating and validating the
    /// stake of each signer against the required stake of the given message type.
    /// @dev The function will revert if the total stake of the signers is less than the required stake.
    /// @param signatures The array of signatures to be verified.
    /// @param message The BridgeMessage to be verified.
    function verifySignatures(bytes[] memory signatures, BridgeMessage.Message memory message)
        public
        view
        override
    {
        uint32 requiredStake = BridgeMessage.requiredStake(message);

        uint16 approvalStake;
        address signer;
        uint256 bitmap;

        // Check validity of each signature and aggregate the approval stake
        for (uint16 i; i < signatures.length; i++) {
            bytes memory signature = signatures[i];
            // recover the signer from the signature
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

            (signer,,) = ECDSA.tryRecover(BridgeMessage.computeHash(message), v, r, s);

            // skip if signer is block listed or has no stake
            if (blocklist[signer] || committeeStake[signer] == 0) continue;

            uint8 index = committeeIndex[signer];
            uint256 mask = 1 << index;
            if (bitmap & mask == 0) {
                bitmap |= mask;
            } else {
                // skip if duplicate signature
                continue;
            }

            approvalStake += committeeStake[signer];
        }

        require(approvalStake >= requiredStake, "BridgeCommittee: Insufficient stake amount");
    }

    /// @notice Updates the blocklist status of the provided addresses if provided signatures are valid.
    /// @param signatures The array of signatures to validate the message.
    /// @param message BridgeMessage containing the update blocklist payload.
    function updateBlocklistWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.BLOCKLIST)
    {
        // decode the blocklist payload
        (bool isBlocklisted, address[] memory _blocklist) =
            BridgeMessage.decodeBlocklistPayload(message.payload);

        // update the blocklist
        _updateBlocklist(_blocklist, isBlocklisted);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @notice Updates the blocklist status of the provided addresses.
    /// @param _blocklist The addresses to update the blocklist status.
    /// @param isBlocklisted new blocklist status.
    function _updateBlocklist(address[] memory _blocklist, bool isBlocklisted) internal {
        // check original blocklist value of each validator
        for (uint16 i; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = isBlocklisted;
        }

        emit BlocklistUpdated(_blocklist, isBlocklisted);
    }

    /// @notice Splits the provided signature into its r, s, and v components.
    /// @param sig The signature to be split.
    /// @return r The r component of the signature.
    /// @return s The s component of the signature.
    /// @return v The v component of the signature.
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
}
