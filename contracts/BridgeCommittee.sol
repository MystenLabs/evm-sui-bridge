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

    /* ========== STATE VARIABLES ========== */

    // address of the bridge contract
    ISuiBridge public bridge;
    // member address => stake amount
    mapping(address => uint256) public committee;
    // member address => is blocklisted
    mapping(address => bool) public blocklist;
    // message hash => approved
    mapping(bytes32 => bool) public messageApproved;
    // message type => required amount of approval stake
    mapping(uint256 => uint256) public requiredApproval;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    constructor(address[] memory _committee, uint256[] memory stake, address _bridge) {
        for (uint256 i = 0; i < _committee.length; i++) {
            committee[_committee[i]] = stake[i];
        }
        bridge = ISuiBridge(_bridge);
        // TOKEN_TRANSFER = 3334
        requiredApproval[TOKEN_TRANSFER] = 3334;
        // BLOCKLIST = 5001
        requiredApproval[BLOCKLIST] = 5001;
        // EMERGENCY_OP (pausing) = 450
        requiredApproval[EMERGENCY_OP] = 450;
        // BRIDGE_UPGRADE = 5001
        requiredApproval[BRIDGE_UPGRADE] = 5001;
        // BRIDGE_OWNERSHIP = 5001
        requiredApproval[BRIDGE_OWNERSHIP] = 5001;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function submitMessageWithSignatures(bytes memory signatures, bytes memory message) external {
        // Prepare the message hash
        bytes32 messageHash = getMessageHash(message);
        // Check that the message has not already been approved
        require(messageApproved[messageHash], "BridgeCommittee: Message already approved");

        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("SUI_NATIVE_BRIDGE", messageHash));

        // Loop over the signatures and check if they are valid
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

            // If signer is block listed skip this signature
            if (blocklist[signer]) continue;

            approvalStake += committee[signer];
        }

        if (checkMessageApproval(message, approvalStake)) {
            // approve message
            messageApproved[getMessageHash(message)] = true;
            _processMessage(message);
        }
    }

    function _processMessage(bytes memory message) private {
        uint256 messageType = decodeMessageType(message);

        if (messageType == BLOCKLIST) {
            (address[] memory validators, bool blocklisted) = decodeBlocklistMessage(message);
            _updateBlocklist(validators, blocklisted);
        } else if (messageType == BRIDGE_UPGRADE) {
            address upgradeImplementation = decodeBridgeUpgradeMessage(message);
            _upgrade(upgradeImplementation);
        } else if (messageType == BRIDGE_OWNERSHIP) {
            address newOwner = decodeBridgeOwnershipMessage(message);
            _transferBridgeOwnership(newOwner);
        } else {
            // if the message type is not for the committee, submit it to the bridge
            bridge.submitMessage(message);
        }
        emit MessageProcessed(message);
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

    function _updateBlocklist(address[] memory _blocklist, bool isBlocklisted) internal {
        for (uint256 i = 0; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = isBlocklisted;
        }
    }

    /* ========== VIEW FUNCTIONS ========== */

    function checkMessageApproval(bytes memory message, uint256 approvalStake)
        public
        view
        returns (bool)
    {
        // Get the message type from the message hash.
        uint256 messageType = decodeMessageType(message);
        // Get the required stake for the message type
        uint256 requiredStake = requiredApproval[messageType];
        if (messageType == EMERGENCY_OP) {
            // decode the emergency op message
            bool isPausing = decodeEmergencyOpMessage(message);
            // if the message is to unpause the bridge, use the upgrade stake requirement
            if (!isPausing) requiredStake = requiredApproval[BRIDGE_UPGRADE];
        }
        // Compare the approval stake with the required stake and return the result
        return approvalStake >= requiredStake;
    }

    function decodeMessageType(bytes memory message) public pure returns (uint256) {
        // Check that the message is not empty
        require(message.length > 0, "Empty message");

        // decode nonce, version, and type from message
        (uint256 nonce, uint256 version, uint256 messageType, bytes memory payload) =
            abi.decode(message, (uint256, uint256, uint256, bytes));

        return (messageType);
    }

    function decodeEmergencyOpMessage(bytes memory message) public pure returns (bool) {
        (uint256 nonce, uint256 version, uint256 messageType, uint256 opCode) =
            abi.decode(message, (uint256, uint256, uint256, uint256));
        // 0 = pausing
        // 1 = unpausing
        return (opCode == 0);
    }

    function decodeBridgeUpgradeMessage(bytes memory message) public pure returns (address) {
        (uint256 nonce, uint256 version, uint256 messageType, address implementationAddress) =
            abi.decode(message, (uint256, uint256, uint256, address));
        return implementationAddress;
    }

    function decodeBridgeOwnershipMessage(bytes memory message) public pure returns (address) {
        (uint256 nonce, uint256 version, uint256 messageType, address newOwner) =
            abi.decode(message, (uint256, uint256, uint256, address));
        return newOwner;
    }

    function decodeBlocklistMessage(bytes memory message)
        public
        pure
        returns (address[] memory, bool)
    {
        // [message_type: u8][version:u8][nonce:u64][blocklist_type: u8][validator_pub_keys: byte[][]]
        (
            uint256 nonce,
            uint256 version,
            uint256 messageType,
            uint256 blocklistType,
            address[] memory validators
        ) = abi.decode(message, (uint256, uint256, uint256, uint256, address[]));
        bool blocklisted = (blocklistType == 0) ? true : false;
        return (validators, blocklisted);
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

    // TODO: see if can pull from OpenZeppelin
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

    // TODO: explore alternatives (OZ may have something)
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

    event MessageProcessed(bytes message);
}
