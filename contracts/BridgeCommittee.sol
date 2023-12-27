// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./utils/Messages.sol";

contract BridgeCommittee is IBridgeCommittee, UUPSUpgradeable {
    /* ========== CONSTANTS ========== */

    uint256 public constant BLOCKLIST_STAKE_REQUIRED = 5001;
    uint256 public constant COMMITTEE_UPGRADE_STAKE_REQUIRED = 5001;

    /* ========== STATE VARIABLES ========== */

    // member address => stake amount
    mapping(address => uint16) public committee;
    // member address => is blocklisted
    mapping(address => bool) public blocklist;
    // messageType => nonce
    mapping(uint256 => uint64) public nonces;

    /* ========== INITIALIZER ========== */

    /// @notice Initializes the contract with the deployer as the admin.
    /// @dev should be called directly after deployment (see OpenZeppelin upgradeable standards).
    function initialize(address[] memory _committee, uint256[] memory stake) external initializer {
        __UUPSUpgradeable_init();
        for (uint256 i = 0; i < _committee.length; i++) {
            committee[_committee[i]] = stake[i];
        }
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function updateBlocklistWithSignatures(bytes memory signatures, bytes memory message)
        external
    {
        Messages.Message memory _message = Messages.decodeMessage(message);

        // verify message type nonce
        require(_message.nonce == nonces[_message.messageType], "BridgeCommittee: Invalid nonce");

        // verify message type
        require(
            _message.messageType == Messages.BLOCKLIST,
            "BridgeCommittee: message does not match type"
        );

        // verify signatures
        require(
            verifyMessageSignatures(signatures, message, BLOCKLIST_STAKE_REQUIRED),
            "BridgeCommittee: Invalid signatures"
        );

        // decode the blocklist payload
        (bool isBlocklisted, address[] memory _blocklist) =
            Messages.decodeBlocklistPayload(_message.payload);

        // update the blocklist
        _updateBlocklist(_blocklist, isBlocklisted);

        // increment message type nonce
        nonces[Messages.BLOCKLIST]++;

        // TODO: emit event
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

        // verify message type nonce
        require(_message.nonce == nonces[_message.messageType], "BridgeCommittee: Invalid nonce");

        // verify signatures
        require(
            verifyMessageSignatures(signatures, message, COMMITTEE_UPGRADE_STAKE_REQUIRED),
            "BridgeCommittee: Invalid signatures"
        );

        // decode the upgrade payload
        address implementationAddress = Messages.decodeUpgradePayload(_message.payload);

        // update the upgrade
        _upgradeCommittee(implementationAddress);

        // increment message type nonce
        nonces[Messages.COMMITTEE_UPGRADE]++;

        // TODO: emit event
    }

    /* ========== VIEW FUNCTIONS ========== */

    function verifyMessageSignatures(
        bytes memory signatures, // Why is this a bytes and not a Signature[]?
        bytes memory message, // Why is this a bytes and not a Message?
        uint256 requiredStake // Is it a good idea to have this as a parameter?
    ) public view override returns (bool) {
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

        return approvalStake >= requiredStake;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _updateBlocklist(address[] memory _blocklist, bool isBlocklisted) internal {
        // check original blocklist value of each validator
        for (uint256 i = 0; i < _blocklist.length; i++) {
            blocklist[_blocklist[i]] = isBlocklisted;
        }
    }

    // TODO:
    function _authorizeUpgrade(address newImplementation) internal override {
        // TODO: implement so only committee members can upgrade
    }

    // TODO: "self upgrading"
    // note: do we want to use "upgradeToAndCall" instead?
    function _upgradeCommittee(address upgradeImplementation)
        internal
        returns (bool, bytes memory)
    {
        // return upgradeTo(upgradeImplementation);
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

    /* ========== EVENTS ========== */

    event MessageProcessed(bytes message);
}
