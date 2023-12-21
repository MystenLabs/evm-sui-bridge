// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/ISuiBridge.sol";

contract BridgeCommittee {
    /* ========== TYPES ========== */

    uint256 public constant TOKEN_TRANSFER = 0;
    uint256 public constant BLOCKLIST = 1;
    uint256 public constant EMERGENCY_OP = 2;
    uint256 public constant BRIDGE_UPGRADE = 3;
    uint256 public constant BRIDGE_OWNERSHIP = 4;

    struct Message {
        uint256 nonce;
        uint256 version;
        uint256 messageType;
        bytes payload;
    }

    /* ========== STATE VARIABLES ========== */

    // address of the bridge contract
    ISuiBridge public bridge;
    // committee nonce
    uint256 public nonce;
    // total committee members stake
    uint256 public totalCommitteeStake;
    // member address => stake amount
    mapping(address => uint256) public committee;
    // member address => is blocklisted
    mapping(address => bool) public blocklist;
    // signer address => nonce => message hash
    mapping(address => mapping(uint256 => bytes32)) public messageApprovals;
    // nonce => message hash => total approvals
    mapping(uint256 => mapping(bytes32 => uint256)) public totalMessageApproval;
    // maps the message types to their required approvals
    mapping(uint256 => uint256) public requiredApprovals;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    constructor(address[] memory _committee, uint256[] memory stake, address _bridge) {
        nonce = 1;
        uint256 _totalCommitteeStake;
        for (uint256 i = 0; i < _committee.length; i++) {
            committee[_committee[i]] = stake[i];
            _totalCommitteeStake += stake[i];
        }
        bridge = ISuiBridge(_bridge);
        totalCommitteeStake = _totalCommitteeStake;

        requiredApprovals[TOKEN_TRANSFER] = totalCommitteeStake / 2 + 1;
        requiredApprovals[EMERGENCY_OP] = 2;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function submitMessageSignatures(bytes memory signatures, bytes memory message) external {
        // Prepare the message hash
        bytes32 messageHash = getMessageHash(message);
        bytes32 ethSignedMessageHash =
            keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));

        uint256 approvalStake;
        address signer;
        uint256 signatureSize = 65;
        for (uint256 i = 0; i < signatures.length; i += signatureSize) {
            // Extract R, S, and V components from the signature
            bytes memory signature = extractSignature(signatures, i, signatureSize);
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

            // Recover the signer address
            signer = ecrecover(ethSignedMessageHash, v, r, s);

            // Check if the signer is a committee member and not already approved
            require(committee[signer] > 0, "BridgeCommittee: Not a committee member");

            // If signer has already approved this message skip this signature
            if (messageApprovals[signer][nonce] == messageHash) continue;

            // If signer is block listed skip this signature
            if (blocklist[signer]) continue;

            // Record the approval
            messageApprovals[signer][nonce] = messageHash;
            approvalStake += committee[signer];

            // Emit the event for this approval
            emit MessageApproved(signer, nonce, message);
        }

        // Update total message approval stake
        totalMessageApproval[nonce][messageHash] += approvalStake;

        if (checkMessageApproval(nonce, message)) {
            _processMessage(message);
        }
    }

    function _processMessage(bytes memory message) private {
        Message memory _message = constructMessage(message);
        uint256 _nonce = _message.nonce;
        uint256 messageType = _message.messageType;
        bytes memory payload = _message.payload;

        require(_nonce == nonce, "BridgeCommittee: Invalid nonce");
        require(checkMessageApproval(nonce, message), "BridgeCommittee: Not enough approvals");

        // if the message type is not for the committee, submit it to the bridge
        if (messageType == BLOCKLIST) {
            address[] memory _blocklist = getAddressesFromPayload(payload);
            _updateBlocklist(_blocklist);
        } else if (messageType == EMERGENCY_OP) {} else if (messageType == BRIDGE_UPGRADE) {
            address upgradeImplementation = getAddressFromPayload(payload);
            _upgrade(upgradeImplementation);
        } else if (messageType == BRIDGE_OWNERSHIP) {
            address newOwner = getAddressFromPayload(payload);
            _transferBridgeOwnership(newOwner);
        } else {
            bridge.submitMessage(message);
        }
        nonce++;
        emit MessageProcessed(nonce, message);
    }

    // TODO: going to need to test this method of upgrading
    // note: upgrading this way will not enable initialization using "upgradeToAndCall". explore more
    function _upgrade(address upgradeImplementation) internal returns (bool, bytes memory) {
        return address(bridge).call(
            abi.encodeWithSignature("upgradeTo(address)", upgradeImplementation)
        );
    }

    function _transferBridgeOwnership(address newOwner) internal {
        bridge.transferOwnership(newOwner);
    }

    function _updateBlocklist(address[] memory _blocklist) internal {
        for (uint256 i = 0; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = true;
        }
    }

    /* ========== VIEW FUNCTIONS ========== */

    function checkMessageApproval(uint256 _nonce, bytes memory _message)
        public
        view
        returns (bool)
    {
        // Get the message hash
        bytes32 messageHash = getMessageHash(_message);

        // Check that the nonce and the message hash are valid.
        require(_nonce > 0, "Invalid nonce");
        require(messageHash != bytes32(0), "Invalid message hash");

        // Get the message type from the message hash.
        uint256 messageType = constructMessage(_message).messageType;
        // Get the required stake for the message type
        uint256 requiredStake = requiredApprovals[messageType];
        // Get the approval stake for the message
        uint256 approvalStake = totalMessageApproval[_nonce][messageHash];
        // Compare the approval stake with the required stake and return the result
        return approvalStake >= requiredStake;
    }

    function getAddressFromPayload(bytes memory payload) public pure returns (address) {
        // Check that the payload is not empty
        require(payload.length > 0, "Empty payload");

        // Extract the first 20 bytes from the payload
        bytes20 addressBytes = bytes20(slice(payload, 0, 20));

        // Cast the bytes to an unsigned integer
        uint160 addressInt = uint160(addressBytes);

        // Cast the integer to an address
        address addressValue = address(addressInt);

        // Return the address
        return addressValue;
    }

    function getAddressesFromPayload(bytes memory payload) public pure returns (address[] memory) {
        // Check that the payload is not empty
        require(payload.length > 0, "Empty payload");

        // Initialize the output array
        address[] memory addresses = new address[](payload.length / 20);

        // Loop over the payload and extract 20 bytes for each address
        for (uint256 i = 0; i < payload.length; i += 20) {
            // Append the address to the output array
            addresses[i / 20] = getAddressFromPayload(slice(payload, i, i + 20));
        }

        // Return the output array
        return addresses;
    }

    function constructMessage(bytes memory message) public pure returns (Message memory) {
        // Check that the message is not empty
        require(message.length > 0, "Empty message");

        // Decode the message into the struct components
        (
            uint256 messageNonce,
            uint256 messageVersion,
            uint256 messageType,
            bytes memory messagePayload
        ) = abi.decode(message, (uint256, uint256, uint256, bytes));

        // Cast the components to the struct type
        Message memory messageStruct =
            Message(messageNonce, messageVersion, messageType, messagePayload);

        // Return the struct
        return messageStruct;
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

    function getMessageHash(bytes memory message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(message));
    }

    // https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
    function slice(bytes memory _bytes, uint256 _start, uint256 _length)
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } { mstore(mc, mload(cc)) }

                mstore(tempBytes, _length)

                //update free-memory pointer
                //allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            //if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                //zero out the 32 bytes slice we are about to return
                //we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    /* ========== EVENTS ========== */

    event MessageApproved(address member, uint256 nonce, bytes message);
    event MessageProcessed(uint256 nonce, bytes message);
}
