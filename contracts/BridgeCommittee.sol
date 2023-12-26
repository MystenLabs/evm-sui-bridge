// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./utils/Messages.sol";

contract BridgeCommittee is IBridgeCommittee, UUPSUpgradeable {
    /* ========== STATE VARIABLES ========== */

    // member address => stake amount
    mapping(address => uint256) public committee;
    // member address => is blocklisted
    mapping(address => bool) public blocklist;
    // message type => required amount of approval stake
    mapping(uint256 => uint256) public requiredApprovalStake;

    mapping(bytes32 => bool) public messageProcessed;

    /* ========== CONSTANTS ========== */

    uint256 public constant CHAIN_ID = 1;
    uint256 public constant DEFAULT_STAKE_REQUIRED = 5001;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    function initialize(address[] memory _committee, uint256[] memory stake) external initializer {
        __UUPSUpgradeable_init();
        for (uint256 i = 0; i < _committee.length; i++) {
            committee[_committee[i]] = stake[i];
        }
        requiredApprovalStake[Messages.TOKEN_TRANSFER] = 3334;
        requiredApprovalStake[Messages.BLOCKLIST] = 5001;
        requiredApprovalStake[Messages.EMERGENCY_OP] = 450;
        requiredApprovalStake[Messages.BRIDGE_UPGRADE] = 5001;
        requiredApprovalStake[Messages.COMMITTEE_UPGRADE] = 5001;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function updateBlocklistWithSignatures(bytes memory signatures, bytes memory message)
        external
    {
        Messages.Message memory _message = Messages.decodeMessage(message);

        // verify message type
        require(
            _message.messageType == Messages.BLOCKLIST,
            "BridgeCommittee: message does not match type"
        );

        // verify signatures
        require(verifyMessageSignatures(signatures, message), "BridgeCommittee: Invalid signatures");

        // decode the blocklist payload
        (bool isBlocklisted, address[] memory _blocklist) =
            Messages.decodeBlocklistPayload(_message.payload);

        // update the blocklist
        _updateBlocklist(_blocklist, isBlocklisted);

        // TODO: emit event

        // mark message as processed
        messageProcessed[Messages.getHash(message)] = true;
    }

    function upgradeCommitteeWithSignatures(bytes memory signatures, bytes memory message)
        external
    {
        Messages.Message memory _message = Messages.decodeMessage(message);

        // verify message type
        require(
            _message.messageType == Messages.COMMITTEE_UPGRADE,
            "BridgeCommittee: message does not match type"
        );

        // verify signatures
        require(verifyMessageSignatures(signatures, message), "BridgeCommittee: Invalid signatures");

        // decode the upgrade payload
        address implementationAddress = Messages.decodeUpgradePayload(_message.payload);

        // update the upgrade
        _upgradeCommittee(implementationAddress);

        // TODO: emit event

        // mark message as processed
        messageProcessed[Messages.getHash(message)] = true;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function verifyMessageSignatures(bytes memory signatures, bytes memory message)
        public
        view
        override
        returns (bool)
    {
        // reconstruct the message in byte format
        bytes memory messageBytes = abi.encode(message);
        // Prepare the message hash
        bytes32 messageHash = Messages.getHash(messageBytes);
        // Check that the message has not already been processed
        require(messageProcessed[messageHash], "BridgeCommittee: Message already processed");

        bytes32 suiSignedMessageHash = keccak256(abi.encodePacked("SUI_NATIVE_BRIDGE", message));

        // Loop over the signatures and check if they are valid
        uint256 approvalStake;
        address signer;
        for (uint256 i = 0; i < signatures.length; i += Messages.SIGNATURE_SIZE) {
            // Extract R, S, and V components from the signature
            bytes memory signature = extractSignature(signatures, i, Messages.SIGNATURE_SIZE);
            (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);

            // Recover the signer address
            signer = ecrecover(suiSignedMessageHash, v, r, s);

            // Check if the signer is a committee member and not already approved
            require(committee[signer] > 0, "BridgeCommittee: Not a committee member");

            // If signer is block listed skip this signature
            if (blocklist[signer]) continue;

            approvalStake += committee[signer];
        }

        return verifyMessageApprovalStake(message, approvalStake);
    }

    function verifyMessageApprovalStake(bytes memory message, uint256 approvalStake)
        public
        view
        returns (bool)
    {
        // TODO: Lu pointed out that it seems redundant to decode the message twice... explore alternatives
        Messages.Message memory _message = Messages.decodeMessage(message);
        // Get the required stake for the message type
        uint256 requiredStake = requiredApprovalStake[_message.messageType];
        if (_message.messageType == Messages.EMERGENCY_OP) {
            // decode the emergency op message
            bool isPausing = Messages.decodeEmergencyOpPayload(message);
            // if the message is to unpause the bridge, use the default stake requirement
            if (!isPausing) requiredStake = requiredApprovalStake[DEFAULT_STAKE_REQUIRED];
        }
        // Compare the approval stake with the required stake and return the result
        return approvalStake >= requiredStake;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    // TODO: test this method of "self upgrading"
    // note: upgrading this way will not enable initialization using "upgradeToAndCall". explore alternatives
    function _upgradeCommittee(address upgradeImplementation)
        internal
        returns (bool, bytes memory)
    {
        return
            address(this).call(abi.encodeWithSignature("upgradeTo(address)", upgradeImplementation));
    }

    function _updateBlocklist(address[] memory _blocklist, bool isBlocklisted) internal {
        // check original blocklist value of each validator
        for (uint256 i = 0; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = isBlocklisted;
        }
    }

    // Helper function to extract a signature from the array
    function extractSignature(bytes memory signatures, uint256 index, uint256 size)
        internal
        pure
        returns (bytes memory)
    {
        require(
            index + size <= signatures.length, "BridgeCommittee: extractSignatures is out of bounds"
        );
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

    // TODO:
    function _authorizeUpgrade(address newImplementation) internal override {
        // TODO: implement so only committee members can upgrade
    }

    /* ========== EVENTS ========== */

    event MessageProcessed(bytes message);
}
