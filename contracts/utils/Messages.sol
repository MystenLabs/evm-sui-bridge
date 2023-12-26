// TODO: thought. Updates to this library may require upgrades to both SuiBridge and BridgeCommittee contracts.
// problematic?

library Messages {
    // message Ids
    uint256 public constant TOKEN_TRANSFER = 0;
    uint256 public constant BLOCKLIST = 1;
    uint256 public constant EMERGENCY_OP = 2;
    uint256 public constant BRIDGE_UPGRADE = 3;
    uint256 public constant COMMITTEE_UPGRADE = 4;

    // token Ids
    uint256 public constant SUI = 0;
    uint256 public constant BTC = 1;
    uint256 public constant ETH = 2;
    uint256 public constant USDC = 3;
    uint256 public constant USDT = 4;

    // constant

    uint256 public constant SIGNATURE_SIZE = 65;

    struct Message {
        uint256 messageType;
        uint256 version;
        uint256 nonce;
        uint256 chainID;
        bytes payload;
    }

    function decodeMessage(bytes memory message) internal pure returns (Message memory) {
        // Check that the message is not empty
        require(message.length > 0, "Empty message");

        // decode nonce, version, and type from message
        (uint256 messageType, uint256 version, uint256 nonce, uint256 chainId, bytes memory payload)
        = abi.decode(message, (uint256, uint256, uint256, uint256, bytes));

        return Message(messageType, version, nonce, chainId, payload);
    }

    function getHash(bytes memory message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(message));
    }
}
