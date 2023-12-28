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

    /* ========== CONSTANTS ========== */

    // Total stake is 10000, u16 is enough
    uint16 public constant TRANSFER_STAKE_REQUIRED = 5001;
    uint16 public constant FREEZING_STAKE_REQUIRED = 450;
    uint16 public constant UNFREEZING_STAKE_REQUIRED = 5001;
    uint16 public constant BRIDGE_UPGRADE_STAKE_REQUIRED = 5001;

    /* ========== STATE VARIABLES ========== */

    IBridgeCommittee public committee;
    IBridgeVault public vault;
    IWETH9 public weth9;
    uint8 public chainId;
    address[] public supportedTokens;
    // message type => required amount of approval stake
    mapping(uint8 => uint16) public requiredApprovalStake;
    // message nonce => processed
    mapping(uint64 => bool) public messageProcessed;
    // TODO: check that garbage collection is not needed for this ^^
    // messageType => nonce
    mapping(uint8 => uint64) public nonces;

    /* ========== INITIALIZER ========== */

    function initialize(
        address[] memory _supportedTokens,
        address _committee,
        address _vault,
        address _weth9,
        uint8 _chainId
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        supportedTokens = _supportedTokens;
        committee = IBridgeCommittee(_committee);
        vault = IBridgeVault(_vault);
        weth9 = IWETH9(_weth9);
        chainId = _chainId;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function transferTokensWithSignatures(
        bytes[] memory signatures,
        Messages.Message memory message
    ) external nonReentrant {
        // verify message type
        require(
            message.messageType == Messages.TOKEN_TRANSFER, "SuiBridge: message does not match type"
        );

        // verify that message has not been processed
        require(!messageProcessed[message.nonce], "SuiBridge: Message already processed");

        // compute message hash
        bytes32 messageHash = Messages.getMessageHash(message);

        // verify signatures
        require(
            committee.verifyMessageSignatures(signatures, messageHash, TRANSFER_STAKE_REQUIRED),
            "SuiBridge: Invalid signatures"
        );

        Messages.TokenTransferPayload memory tokenTransferPayload =
            decodeTokenTransferPayload(message.payload);

        _transferTokensFromVault(
            tokenTransferPayload.tokenType,
            tokenTransferPayload.targetAddress,
            tokenTransferPayload.amount
        );

        // mark message as processed
        messageProcessed[message.nonce] = true;
    }

    function executeEmergencyOpWithSignatures(
        bytes[] memory signatures,
        Messages.Message memory message
    ) external nonReentrant {
        // verify message type nonce
        require(message.nonce == nonces[message.messageType], "SuiBridge: Invalid nonce");

        // verify message type
        require(
            message.messageType == Messages.EMERGENCY_OP, "SuiBridge: message does not match type"
        );

        // calculate required stake
        uint16 stakeRequired = UNFREEZING_STAKE_REQUIRED;

        // decode the emergency op message
        bool isFreezing = decodeEmergencyOpPayload(message.payload);

        // if the message is to unpause the bridge, use the default stake requirement
        if (isFreezing) stakeRequired = FREEZING_STAKE_REQUIRED;

        // compute message hash
        bytes32 messageHash = Messages.getMessageHash(message);

        // verify signatures
        require(
            committee.verifyMessageSignatures(signatures, messageHash, stakeRequired),
            "SuiBridge: Invalid signatures"
        );

        if (isFreezing) _pause();
        else _unpause();

        // increment message type nonce
        nonces[Messages.EMERGENCY_OP]++;
    }

    function upgradeBridgeWithSignatures(bytes[] memory signatures, Messages.Message memory message)
        external
    {
        // verify message type nonce
        require(message.nonce == nonces[message.messageType], "SuiBridge: Invalid nonce");

        // verify message type
        require(
            message.messageType == Messages.BRIDGE_UPGRADE, "SuiBridge: message does not match type"
        );

        // compute message hash
        bytes32 messageHash = Messages.getMessageHash(message);

        // verify signatures
        require(
            committee.verifyMessageSignatures(
                signatures, messageHash, BRIDGE_UPGRADE_STAKE_REQUIRED
            ),
            "SuiBridge: Invalid signatures"
        );

        // decode the upgrade payload
        address implementationAddress = decodeUpgradePayload(message.payload);

        // update the upgrade
        _upgradeBridge(implementationAddress);

        // increment message type nonce
        nonces[Messages.BRIDGE_UPGRADE]++;
    }

    function bridgeToSui(
        uint8 tokenId,
        uint256 amount,
        bytes memory targetAddress,
        uint8 destinationChainId
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

        // increment token transfer nonce
        nonces[Messages.TOKEN_TRANSFER]++;

        emit TokensBridgedToSui(
            tokenId,
            amount,
            targetAddress,
            destinationChainId,
            chainId,
            nonces[Messages.TOKEN_TRANSFER]
        );
    }

    function bridgeETHToSui(bytes memory targetAddress, uint8 destinationChainId)
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

        // increment token transfer nonce
        nonces[Messages.TOKEN_TRANSFER]++;

        emit TokensBridgedToSui(
            Messages.ETH,
            amount,
            targetAddress,
            destinationChainId,
            chainId,
            nonces[Messages.TOKEN_TRANSFER]
        );
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _transferTokensFromVault(uint8 tokenType, address targetAddress, uint256 amount)
        internal
        whenNotPaused
    {
        address tokenAddress = supportedTokens[tokenType - 1];

        // Check that the token address is supported
        require(tokenAddress != address(0), "SuiBridge: Unsupported token");

        // TODO: convert amount to relevant decimals

        // transfer tokens from vault to target address
        vault.transferERC20(tokenAddress, targetAddress, amount);
    }

    function decodeEmergencyOpPayload(bytes memory payload) internal pure returns (bool) {
        (uint256 emergencyOpCode) = abi.decode(payload, (uint256));
        require(emergencyOpCode <= 1, "Messages: Invalid op code");

        if (emergencyOpCode == 0) {
            return true;
        } else if (emergencyOpCode == 1) {
            return false;
        } else {
            revert("Invalid emergency operation code");
        }
    }

    function decodeTokenTransferPayload(bytes memory payload)
        internal
        pure
        returns (Messages.TokenTransferPayload memory)
    {
        (Messages.TokenTransferPayload memory tokenTransferPayload) =
            abi.decode(payload, (Messages.TokenTransferPayload));

        return tokenTransferPayload;
    }

    function decodeUpgradePayload(bytes memory payload) internal pure returns (address) {
        (address implementationAddress) = abi.decode(payload, (address));
        return implementationAddress;
    }

    // TODO: "self upgrading"
    // note: do we want to use "upgradeToAndCall" instead?
    function _upgradeBridge(address upgradeImplementation) internal returns (bool, bytes memory) {
        // return upgradeTo(upgradeImplementation);
    }

    // TODO:
    function _authorizeUpgrade(address newImplementation) internal override {
        // TODO: implement so only committee members can upgrade
    }
}
