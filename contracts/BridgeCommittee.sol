// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NOTE: THIS CONTRACT IS THE OWNER OF THE SUIBRIDGE CONTRACT

contract BridgeCommittee {
    /* ========== TYPES ========== */

    enum ActionType {
        ADD_MEMBER,
        REMOVE_MEMBER,
        TRANSFER_MEMBER,
        UPGRADE_BRIDGE,
        TRANSFER_BRIDGE_OWNERSHIP,
        SEND_BRIDGE_MESSAGE
    }

    /* ========== STATE VARIABLES ========== */

    // committee nonce
    uint256 public nonce;
    // total committee members
    uint256 public totalCommitteeMembers;
    // member address => is committee member
    mapping(address => bool) public committee;
    // nominator => nominee => nominationStatus
    mapping(address => mapping(address => bool)) public nominations;
    // committee member => total nominations
    mapping(address => uint256) public totalNominations;
    // signer address => nonce => action hash
    mapping(address => mapping(uint256 => bytes32)) public actionApprovals;
    // nonce => action hash => total approvals
    mapping(uint256 => mapping(bytes32 => uint256)) public totalActionApprovals;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    constructor() {
        nonce = 1;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function submitActionSignatures(
        bytes memory signatures,
        uint256 _nonce,
        ActionType actionType,
        bytes memory payload
    ) external {
        // Prepare the message hash
        bytes32 actionHash = keccak256(abi.encodePacked(_nonce, actionType, payload));
        bytes32 ethSignedMessageHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", actionHash));

        uint256 approvals;
        address signer;
        uint256 signatureSize = 65;
        for (uint256 i = 0; i < signatures.length; i += signatureSize) {
            // Extract R, S, and V components from the signature
            bytes memory signature = extractSignature(signatures, i, signatureSize);
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

            // Recover the signer address
            signer = ecrecover(ethSignedMessageHash, v, r, s);

            // Check if the signer is a committee member and not already approved
            require(committee[signer], "BridgeCommittee: Not a committee member");
            // TODO: Check that signer has not already approved the payload
            // require(currentHash != payload, "BridgeCommittee: Duplicate approval");

            // Record the approval
            actionApprovals[signer][nonce] = actionHash;
            approvals++;

            // Emit the event for this approval
            emit ActionApproved(signer, nonce, payload);
        }

        // Update total approvals
        totalActionApprovals[nonce][actionHash] += approvals;

        if (checkActionApproval(nonce, actionHash)) {
            executeAction(_nonce, actionType, payload);
        }
    }

    function executeAction(uint256 _nonce, ActionType actionType, bytes memory payload) public {
        // check that action has enough approvals
        bytes32 actionHash = keccak256(abi.encodePacked(_nonce, actionType, payload));

        require(checkActionApproval(_nonce, actionHash), "BridgeCommittee: Not enough approvals");

        if (actionType == ActionType.ADD_MEMBER) {
            address member = getAddressFromPayload(payload);
            _addMember(member);
        } else if (actionType == ActionType.REMOVE_MEMBER) {
            address member = getAddressFromPayload(payload);
            _removeMember(member);
        } else if (actionType == ActionType.TRANSFER_MEMBER) {
            (address member, address newMember) = getAddressesFromPayload(payload);
            _transferMember(member, newMember);
        } else if (actionType == ActionType.UPGRADE_BRIDGE) {
            address upgradeImplementation = getAddressFromPayload(payload);
            _upgrade(upgradeImplementation);
        } else if (actionType == ActionType.TRANSFER_BRIDGE_OWNERSHIP) {
            address newOwner = getAddressFromPayload(payload);
            _transferBridgeOwnership(newOwner);
        } else if (actionType == ActionType.SEND_BRIDGE_MESSAGE) {
            bytes memory message = getMessageFromPayload(payload);
            _sendMessage(message);
        }
        nonce++;
    }

    function _addMember(address member) internal {
        require(!committee[member], "BridgeCommittee: Member already exists");
        committee[member] = true;
    }

    function _removeMember(address member) internal {
        require(committee[member], "BridgeCommittee: Member does not exist");
        committee[member] = false;
    }

    function _transferMember(address member, address newMember) internal {
        require(committee[member], "BridgeCommittee: Member does not exist");
        require(!committee[newMember], "BridgeCommittee: New member already exists");
        committee[member] = false;
        committee[newMember] = true;
    }

    function _sendMessage(bytes memory message) internal {
        // TODO: send message to SuiBridge
    }

    function _upgrade(address upgradeImplementation) internal {
        // TODO: upgrade SuiBridge
    }

    function _transferBridgeOwnership(address newOwner) internal {
        // TODO: transfer ownership of SuiBridge
    }

    /* ========== VIEW FUNCTIONS ========== */

    function checkActionApproval(uint256 _nonce, bytes32 actionHash) public view returns (bool) {
        // the required approvals is a majority of total committee members
        uint256 requiredApprovals = totalCommitteeMembers / 2 + 1;
        uint256 approvals = totalActionApprovals[_nonce][actionHash];
        return approvals >= requiredApprovals;
    }

    function checkMemberNominations(address member) public view returns (bool) {
        // the required nomination is at least a third of total committee members
        uint256 requiredNominations = totalCommitteeMembers / 3 + 1;
        uint256 _nominations = totalNominations[member];
        return _nominations >= requiredNominations;
    }

    function getAddressFromPayload(bytes memory payload) public pure returns (address) {
        // TODO: extract member from payload
    }

    function getAddressesFromPayload(bytes memory payload) public pure returns (address, address) {
        // TODO: extract member and newMember from payload
    }

    function getMessageFromPayload(bytes memory payload) public pure returns (bytes memory) {
        // TODO; extract message from payload
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    // Helper function to extract a signature from the array
    function extractSignature(bytes memory signatures, uint256 index, uint256 size)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory signature = new bytes(size);
        for (uint256 i = 0; i < size; i++) {
            signature[i] = signatures[index + i];
        }
        return signature;
    }

    // Helper function to split a signature into R, S, and V components
    function splitSignature(bytes memory sig)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(sig.length == 65, "Invalid signature length");

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

    event ActionApproved(address member, uint256 nonce, bytes action);
}
