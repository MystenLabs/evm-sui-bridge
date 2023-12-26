pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./interfaces/ISuiBridge.sol";
import "./utils/Messages.sol";

contract SuiBridge is
    ISuiBridge,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeMath for uint256;

    IBridgeCommittee public committee;
    IBridgeVault public vault;
    IWETH9 public weth9;

    // messageHash => processed
    mapping(bytes32 => bool) public messageProcessed;
    // messageType => nonce
    mapping(uint256 => uint256) public nonces;

    uint256 public bridgeNonce;

    address[] public supportedTokens;

    function initialize(
        address[] memory _supportedTokens,
        address _committee,
        address _vault,
        address _weth9
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        supportedTokens = _supportedTokens;
        committee = IBridgeCommittee(_committee);
        vault = IBridgeVault(_vault);
        weth9 = IWETH9(_weth9);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function transferTokensWithSignatures(bytes memory signatures, bytes memory message)
        external
        nonReentrant
    {
        Messages.Message memory _message = Messages.decodeMessage(message);

        // get message hash
        bytes32 messageHash = Messages.getHash(message);

        // verify signatures
        require(
            committee.verifyMessageSignatures(signatures, message),
            "BridgeCommittee: Invalid signatures"
        );

        // verify that message has not been processed
        require(!messageProcessed[messageHash], "BridgeCommittee: Message already processed");

        // verify message type
        require(
            _message.messageType == Messages.TOKEN_TRANSFER,
            "BridgeCommittee: message does not match type"
        );

        TokenTransferPayload memory tokenTransferPayload =
            decodeTokenTransferPayload(_message.payload);

        _transferTokensFromVault(
            tokenTransferPayload.tokenType,
            tokenTransferPayload.targetAddress,
            tokenTransferPayload.amount
        );

        // mark message as processed
        messageProcessed[messageHash] = true;
    }

    function executeEmergencyOpWithSignatures(bytes memory signatures, bytes memory message)
        external
        nonReentrant
    {
        Messages.Message memory _message = Messages.decodeMessage(message);

        // get message hash
        bytes32 messageHash = Messages.getHash(message);

        // verify message type nonce
        require(_message.nonce == nonces[_message.messageType], "BridgeCommittee: Invalid nonce");

        // verify signatures
        require(
            committee.verifyMessageSignatures(signatures, message),
            "BridgeCommittee: Invalid signatures"
        );

        // verify that message has not been processed
        require(!messageProcessed[messageHash], "BridgeCommittee: Message already processed");

        // verify message type
        require(
            _message.messageType == Messages.EMERGENCY_OP,
            "BridgeCommittee: message does not match type"
        );

        bool isFreezing = decodeEmergencyOpPayload(_message.payload);
        if (isFreezing) _pause();
        else _unpause();

        // mark message as processed
        messageProcessed[messageHash] = true;

        // increment message type nonce
        nonces[_message.messageType]++;
    }

    function upgradeBridgeWithSignatures(bytes memory signatures, bytes memory message) external {
        Messages.Message memory _message = Messages.decodeMessage(message);

        // get message hash
        bytes32 messageHash = Messages.getHash(message);

        // verify message type nonce
        require(_message.nonce == nonces[_message.messageType], "BridgeCommittee: Invalid nonce");

        // verify signatures
        require(
            committee.verifyMessageSignatures(signatures, message), "SuiBridge: Invalid signatures"
        );

        // verify that message has not been processed
        require(!messageProcessed[messageHash], "BridgeCommittee: Message already processed");

        // verify message type
        require(
            _message.messageType == Messages.COMMITTEE_UPGRADE,
            "SuiBridge: message does not match type"
        );

        // decode the upgrade payload
        address implementationAddress = decodeUpgradePayload(_message.payload);

        // update the upgrade
        _upgradeBridge(implementationAddress);

        // mark message as processed
        messageProcessed[messageHash] = true;

        // increment message type nonce
        nonces[_message.messageType]++;
    }

    function bridgeToSui(
        uint256 tokenId,
        uint256 amount,
        bytes memory targetAddress,
        uint256 destinationChainId
    ) external whenNotPaused nonReentrant {
        // Round amount down to nearest whole 8 decimal place (Sui only has 8 decimal places)
        amount = amount.div(10 ** 10).mul(10 ** 10);

        // Check that the token address is supported (but not sui yet)
        require(tokenId > Messages.SUI && tokenId <= Messages.USDT, "SuiBridge: Unsupported token");

        address tokenAddress = supportedTokens[tokenId - 1];

        // check that the bridge contract has allowance to transfer the tokens
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "SuiBridge: Insufficient allowance"
        );

        // Transfer the tokens from the contract to the vault
        IERC20(tokenAddress).transferFrom(msg.sender, address(vault), amount);

        // increment bridge nonce
        bridgeNonce++;

        emit TokensBridgedToSui(tokenId, amount, targetAddress, destinationChainId, bridgeNonce);
    }

    function bridgeETHToSui(bytes memory targetAddress, uint256 destinationChainId)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        // Round amount down to nearest whole 8 decimal place (Sui only has 8 decimal places)
        // Divide by 10^10 to remove the last 10 decimals. Multiply by 10^10 to restore the 18 decimals
        // Use SafeMath to prevent overflows and underflows
        uint256 amount = msg.value.div(10 ** 10).mul(10 ** 10);

        // Wrap ETH
        weth9.deposit{value: amount}();

        // Transfer the wrapped ETH back to caller
        weth9.transfer(address(vault), amount);

        // increment bridge nonce
        bridgeNonce++;

        emit TokensBridgedToSui(
            Messages.ETH, amount, targetAddress, destinationChainId, bridgeNonce
            );
    }

    /* ========== VIEW FUNCTIONS ========== */

    function decodeTokenTransferPayload(bytes memory payload)
        public
        pure
        returns (TokenTransferPayload memory)
    {
        (TokenTransferPayload memory tokenTransferPayload) =
            abi.decode(payload, (TokenTransferPayload));

        return tokenTransferPayload;
    }

    function decodeEmergencyOpPayload(bytes memory payload) public pure returns (bool) {
        (uint256 emergencyOpCode) = abi.decode(payload, (uint256));
        require(emergencyOpCode <= 1, "SuiBridge: Invalid op code");

        if (emergencyOpCode == 0) return true;
        else if (emergencyOpCode == 1) return false;
    }

    function decodeUpgradePayload(bytes memory payload) public pure returns (address) {
        (address implementationAddress) = abi.decode(payload, (address));
        return implementationAddress;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _transferTokensFromVault(uint256 tokenType, address targetAddress, uint256 amount)
        internal
        whenNotPaused
    {
        address tokenAddress = supportedTokens[tokenType];

        // Check that the token address is supported
        require(tokenAddress != address(0), "SuiBridge: Unsupported token");

        // transfer tokens from vault to target address
        vault.transferERC20(tokenAddress, targetAddress, amount);
    }

    // TODO: test this method of "self upgrading"
    // note: upgrading this way will not enable initialization using "upgradeToAndCall". explore more
    function _upgradeBridge(address upgradeImplementation) internal returns (bool, bytes memory) {
        return
            address(this).call(abi.encodeWithSignature("upgradeTo(address)", upgradeImplementation));
    }

    // TODO:
    function _authorizeUpgrade(address newImplementation) internal override {
        // TODO: implement so only committee members can upgrade
    }
}
