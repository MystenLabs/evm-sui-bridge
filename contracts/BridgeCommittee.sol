// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// NOTE: THIS CONTRACT IS THE OWNER OF THE SUIBRIDGE CONTRACT

contract BridgeCommittee {
    /* ========== TYPES ========== */

    struct Message {
        uint256 nonce;
        uint256 version;
        MessageType messageType;
        bytes payload;
    }

    enum MessageType {
        SEND_BRIDGE_MESSAGE,
        ADD_MEMBER,
        REMOVE_MEMBER,
        TRANSFER_MEMBER,
        UPGRADE_BRIDGE,
        TRANSFER_BRIDGE_OWNERSHIP
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
    // signer address => nonce => message hash
    mapping(address => mapping(uint256 => bytes32)) public messageApprovals;
    // nonce => message hash => total approvals
    mapping(uint256 => mapping(bytes32 => uint256)) public totalMessageApprovals;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    constructor() {
        nonce = 1;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function submitMessageSignatures(bytes memory signatures, bytes memory message) external {
        // Prepare the message hash
        bytes32 messageHash = keccak256(abi.encodePacked(message));
        bytes32 ethSignedMessageHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

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
            // TODO: Check that signer has not already approved the message

            // Record the approval
            messageApprovals[signer][nonce] = messageHash;
            approvals++;

            // Emit the event for this approval
            emit MessageApproved(signer, nonce, message);
        }

        // Update total approvals
        totalMessageApprovals[nonce][messageHash] += approvals;

        if (checkMessageApproval(nonce, messageHash)) {
            processMessage(message);
        }
    }

    function processMessage(bytes memory message) public {
        bytes32 messageHash = keccak256(abi.encodePacked());
        Message memory _message = initMessage(message);
        uint256 _nonce = _message.nonce;
        MessageType messageType = _message.messageType;
        bytes memory payload = _message.payload;

        require(_nonce == nonce, "BridgeCommittee: Invalid nonce");
        require(checkMessageApproval(nonce, messageHash), "BridgeCommittee: Not enough approvals");

        if (messageType == MessageType.ADD_MEMBER) {
            address member = getAddressFromPayload(payload);
            _addMember(member);
        } else if (messageType == MessageType.REMOVE_MEMBER) {
            address member = getAddressFromPayload(payload);
            _removeMember(member);
        } else if (messageType == MessageType.TRANSFER_MEMBER) {
            (address member, address newMember) = getAddressesFromPayload(payload);
            _transferMember(member, newMember);
        } else if (messageType == MessageType.UPGRADE_BRIDGE) {
            address upgradeImplementation = getAddressFromPayload(payload);
            _upgrade(upgradeImplementation);
        } else if (messageType == MessageType.TRANSFER_BRIDGE_OWNERSHIP) {
            address newOwner = getAddressFromPayload(payload);
            _transferBridgeOwnership(newOwner);
        } else if (messageType == MessageType.SEND_BRIDGE_MESSAGE) {
            _sendMessage(message);
        }
        nonce++;
        emit MessageProcessed(nonce, message);
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

    function checkMessageApproval(uint256 _nonce, bytes32 messageHash) public view returns (bool) {
        // the required approvals is a majority of total committee members
        uint256 requiredApprovals = totalCommitteeMembers / 2 + 1;
        uint256 approvals = totalMessageApprovals[_nonce][messageHash];
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

    function initMessage(bytes memory message) internal pure returns (Message memory) {
        // TODO: extract message struct from message bytes
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

    event MessageApproved(address member, uint256 nonce, bytes message);
    event MessageProcessed(uint256 nonce, bytes message);
}
