// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/IBridgeLimiter.sol";
import "./interfaces/IBridgeCommittee.sol";
import "./interfaces/ISuiBridge.sol";
import "./utils/BridgeMessage.sol";

/// @title SuiBridge
/// @dev This contract implements a bridge between Ethereum and another blockchain. It allows users to transfer tokens and ETH between the two blockchains. The bridge supports multiple tokens and implements various security measures such as message verification, stake requirements, and upgradeability.
contract SuiBridge is
    ISuiBridge,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    /* ========== CONSTANTS ========== */

    uint32 public constant TRANSFER_STAKE_REQUIRED = 5001;
    uint32 public constant FREEZING_STAKE_REQUIRED = 450;
    uint32 public constant UNFREEZING_STAKE_REQUIRED = 5001;
    uint32 public constant BRIDGE_UPGRADE_STAKE_REQUIRED = 5001;

    /* ========== STATE VARIABLES ========== */

    IBridgeCommittee public committee;
    IBridgeVault public vault;
    IBridgeLimiter public limiter;
    IWETH9 public weth9;
    uint8 public chainId;
    // token id => token address
    mapping(uint8 => address) public supportedTokens;
    // message nonce => processed
    mapping(uint64 => bool) public messageProcessed;
    // messageType => nonce
    mapping(uint8 => uint64) public nonces;

    /* ========== INITIALIZER ========== */

    /// @dev Initializes the SuiBridge contract with the provided parameters.
    /// @param _committee The address of the bridge committee contract.
    /// @param _vault The address of the bridge vault contract.
    /// @param _limiter The address of the bridge limiter contract.
    /// @param _weth9 The address of the WETH9 contract.
    /// @param _chainId The chain ID of the network.
    /// @param _supportedTokens An array of addresses representing the supported tokens.
    function initialize(
        address _committee,
        address _vault,
        address _limiter,
        address _weth9,
        uint8 _chainId,
        address[] memory _supportedTokens
    ) external initializer {
        __ReentrancyGuard_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        for (uint8 i = 0; i < _supportedTokens.length; i++) {
            // skip 0 for SUI
            supportedTokens[i + 1] = _supportedTokens[i];
        }
        committee = IBridgeCommittee(_committee);
        vault = IBridgeVault(_vault);
        limiter = IBridgeLimiter(_limiter);
        weth9 = IWETH9(_weth9);
        chainId = _chainId;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @dev Transfers tokens with signatures.
    /// @param signatures The array of signatures.
    /// @param message The BridgeMessage containing the transfer details.
    function transferTokensWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external nonReentrant {
        // verify message type
        require(
            message.messageType == BridgeMessage.TOKEN_TRANSFER,
            "SuiBridge: message does not match type"
        );

        // verify that message has not been processed
        require(!messageProcessed[message.nonce], "SuiBridge: Message already processed");

        // verify signatures
        require(
            committee.verifyMessageSignatures(
                signatures, BridgeMessage.getMessageHash(message), TRANSFER_STAKE_REQUIRED
            ),
            "SuiBridge: Invalid signatures"
        );

        BridgeMessage.TokenTransferPayload memory tokenTransferPayload =
            decodeTokenTransferPayload(message.payload);

        address tokenAddress = supportedTokens[tokenTransferPayload.tokenId];
        uint8 erc20Decimal = IERC20Metadata(tokenAddress).decimals();
        uint256 erc20AdjustedAmount = adjustDecimalsForErc20(
            tokenTransferPayload.tokenId, tokenTransferPayload.amount, erc20Decimal
        );
        _transferTokensFromVault(
            tokenTransferPayload.tokenId, tokenTransferPayload.targetAddress, erc20AdjustedAmount
        );

        // mark message as processed
        messageProcessed[message.nonce] = true;
    }

    /// @dev Executes an emergency operation with the provided signatures and message.
    /// @param signatures The array of signatures to verify.
    /// @param message The BridgeMessage containing the details of the operation.
    /// Requirements:
    /// - The message nonce must match the nonce for the message type.
    /// - The message type must be EMERGENCY_OP.
    /// - The required stake must be calculated based on the freezing status of the bridge.
    /// - The signatures must be valid and meet the required stake.
    /// - The message type nonce will be incremented.
    function executeEmergencyOpWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external nonReentrant {
        // verify message type nonce
        require(message.nonce == nonces[message.messageType], "SuiBridge: Invalid nonce");

        // verify message type
        require(
            message.messageType == BridgeMessage.EMERGENCY_OP,
            "SuiBridge: message does not match type"
        );

        // calculate required stake
        uint32 stakeRequired = UNFREEZING_STAKE_REQUIRED;

        // decode the emergency op message
        bool isFreezing = decodeEmergencyOpPayload(message.payload);

        // if the message is to unpause the bridge, use the default stake requirement
        if (isFreezing) stakeRequired = FREEZING_STAKE_REQUIRED;

        // verify signatures
        require(
            committee.verifyMessageSignatures(
                signatures, BridgeMessage.getMessageHash(message), stakeRequired
            ),
            "SuiBridge: Invalid signatures"
        );

        if (isFreezing) _pause();
        else _unpause();

        // increment message type nonce
        nonces[BridgeMessage.EMERGENCY_OP]++;
    }

    /// @dev Upgrades the bridge contract with the provided signatures and message.
    /// @param signatures The array of signatures to verify.
    /// @param message The BridgeMessage containing the upgrade details.
    /// Requirements:
    /// - The message nonce must match the nonce for the message type.
    /// - The message type must be BRIDGE_UPGRADE.
    /// - The signatures must be valid.
    /// - The upgrade payload must be decoded successfully.
    /// - The bridge upgrade must be performed successfully.
    /// - The message type nonce must be incremented.
    function upgradeBridgeWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external nonReentrant {
        // verify message type nonce
        require(message.nonce == nonces[message.messageType], "SuiBridge: Invalid nonce");

        // verify message type
        require(
            message.messageType == BridgeMessage.BRIDGE_UPGRADE,
            "SuiBridge: message does not match type"
        );

        // verify signatures
        require(
            committee.verifyMessageSignatures(
                signatures, BridgeMessage.getMessageHash(message), BRIDGE_UPGRADE_STAKE_REQUIRED
            ),
            "SuiBridge: Invalid signatures"
        );

        // decode the upgrade payload
        address implementationAddress = decodeUpgradePayload(message.payload);

        // update the upgrade
        _upgradeBridge(implementationAddress);

        // increment message type nonce
        nonces[BridgeMessage.BRIDGE_UPGRADE]++;
    }

    /// @dev Bridges tokens from the current chain to the Sui chain.
    /// @param tokenId The ID of the token to be bridged.
    /// @param amount The amount of tokens to be bridged.
    /// @param targetAddress The address on the Sui chain where the tokens will be sent.
    /// @param destinationChainId The ID of the destination chain.
    function bridgeToSui(
        uint8 tokenId,
        uint256 amount,
        bytes memory targetAddress,
        uint8 destinationChainId
    ) external whenNotPaused nonReentrant {
        // TODO: add checks for destination chain ID. Disallow invalid values

        // Check that the token address is supported (but not sui yet)
        require(
            tokenId > BridgeMessage.SUI && tokenId <= BridgeMessage.USDT,
            "SuiBridge: Unsupported token"
        );

        address tokenAddress = supportedTokens[tokenId];

        // check that the bridge contract has allowance to transfer the tokens
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "SuiBridge: Insufficient allowance"
        );

        // Transfer the tokens from the contract to the vault
        IERC20(tokenAddress).transferFrom(msg.sender, address(vault), amount);

        // Adjust the amount to log.
        uint64 suiAdjustedAmount =
            adjustDecimalsForSuiToken(tokenId, amount, IERC20Metadata(tokenAddress).decimals());
        emit TokensBridgedToSui(
            chainId,
            nonces[BridgeMessage.TOKEN_TRANSFER],
            destinationChainId,
            tokenId,
            suiAdjustedAmount,
            msg.sender,
            targetAddress
            );

        // increment token transfer nonce
        nonces[BridgeMessage.TOKEN_TRANSFER]++;
    }

    /// @dev Bridges ETH to SUI tokens on a specified destination chain.
    /// @param targetAddress The address on the destination chain where the SUI tokens will be sent.
    /// @param destinationChainId The ID of the destination chain.
    function bridgeETHToSui(bytes memory targetAddress, uint8 destinationChainId)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        // TODO: add checks for destination chain ID. Disallow invalid values

        uint256 amount = msg.value;

        // Wrap ETH
        weth9.deposit{value: amount}();

        // Transfer the wrapped ETH back to caller
        weth9.transfer(address(vault), amount);

        // Adjust the amount to log.
        uint64 suiAdjustedAmount = adjustDecimalsForSuiToken(BridgeMessage.ETH, amount, 18);
        emit TokensBridgedToSui(
            chainId,
            nonces[BridgeMessage.TOKEN_TRANSFER],
            destinationChainId,
            BridgeMessage.ETH,
            suiAdjustedAmount,
            msg.sender,
            targetAddress
            );

        // increment token transfer nonce
        nonces[BridgeMessage.TOKEN_TRANSFER]++;
    }

    /// @dev Adjusts the ERC20 token amount to Sui Coin amount to cover the decimal differences.
    /// @param tokenId The ID of the Sui Coin token.
    /// @param originalAmount The original amount of the ERC20 token.
    /// @param ethDecimal The decimal places of the ERC20 token.
    /// @return The adjusted amount in Sui Coin with decimal places.
    function adjustDecimalsForSuiToken(uint8 tokenId, uint256 originalAmount, uint8 ethDecimal)
        public
        pure
        returns (uint64)
    {
        uint8 suiDecimal = getDecimalOnSui(tokenId);

        if (ethDecimal == suiDecimal) {
            // Ensure the converted amount fits within uint64
            require(originalAmount <= type(uint64).max, "Amount too large for uint64");
            return uint64(originalAmount);
        }

        // Safe guard for the future
        require(ethDecimal > suiDecimal, "Eth decimal should be larger than sui decimal");

        // Difference in decimal places
        uint256 factor = 10 ** (ethDecimal - suiDecimal);
        uint256 newAmount = originalAmount / factor;

        // Ensure the converted amount fits within uint64
        require(newAmount <= type(uint64).max, "Amount too large for uint64");

        return uint64(newAmount);
    }

    /// @dev Adjusts the Sui coin amount to ERC20 amount to cover the decimal differences.
    /// @param tokenId The ID of the token.
    /// @param originalAmount The original amount of Sui coins.
    /// @param ethDecimal The decimal places of the ERC20 token.
    /// @return The adjusted amount in ERC20 token.
    function adjustDecimalsForErc20(uint8 tokenId, uint64 originalAmount, uint8 ethDecimal)
        public
        pure
        returns (uint256)
    {
        uint8 suiDecimal = getDecimalOnSui(tokenId);
        if (suiDecimal == ethDecimal) {
            return uint256(originalAmount);
        }

        // Safe guard for the future
        require(ethDecimal > suiDecimal, "Eth decimal should be larger than sui decimal");

        // Difference in decimal places
        uint256 factor = 10 ** (ethDecimal - suiDecimal);
        uint256 newAmount = originalAmount * factor;

        return newAmount;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @dev Retrieves the decimal value of a token on the SuiBridge contract.
    /// @param tokenId The ID of the token.
    /// @return The decimal value of the token on SuiBridge.
    /// @dev Reverts if the token ID does not have a Sui decimal set.
    function getDecimalOnSui(uint8 tokenId) internal pure returns (uint8) {
        if (tokenId == BridgeMessage.SUI) {
            return BridgeMessage.SUI_DECIMAL_ON_SUI;
        } else if (tokenId == BridgeMessage.BTC) {
            return BridgeMessage.BTC_DECIMAL_ON_SUI;
        } else if (tokenId == BridgeMessage.ETH) {
            return BridgeMessage.ETH_DECIMAL_ON_SUI;
        } else if (tokenId == BridgeMessage.USDC) {
            return BridgeMessage.USDC_DECIMAL_ON_SUI;
        } else if (tokenId == BridgeMessage.USDT) {
            return BridgeMessage.USDT_DECIMAL_ON_SUI;
        }
        revert("TokenId does not have Sui decimal set");
    }

    /// @dev Transfers tokens from the vault to a target address.
    /// @param tokenId The ID of the token being transferred.
    /// @param targetAddress The address to which the tokens are being transferred.
    /// @param amount The amount of tokens being transferred.
    function _transferTokensFromVault(uint8 tokenId, address targetAddress, uint256 amount)
        internal
        whenNotPaused
        willNotExceedLimit(tokenId, amount)
    {
        // transfer eth if token type is eth
        if (tokenId == BridgeMessage.ETH) {
            vault.transferETH(payable(targetAddress), amount);
            return;
        }

        address tokenAddress = supportedTokens[tokenId];

        // Check that the token address is supported
        require(tokenAddress != address(0), "SuiBridge: Unsupported token");

        // transfer tokens from vault to target address
        vault.transferERC20(tokenAddress, targetAddress, amount);

        // update daily amount bridged
        limiter.updateDailyAmountBridged(tokenId, amount);
    }

    /// @dev Decodes the emergency operation payload and checks if it is a valid operation code. The emergency operation code must be either 0 or 1. If it is 0, it returns true. If it is 1, it returns false. If the emergency operation code is neither 0 nor 1, it reverts with an error message.
    /// @param payload The payload to decode.
    /// @return A boolean indicating whether the emergency operation is true or false.
    function decodeEmergencyOpPayload(bytes memory payload) internal pure returns (bool) {
        (uint256 emergencyOpCode) = abi.decode(payload, (uint256));
        require(emergencyOpCode <= 1, "SuiBridge: Invalid op code");

        if (emergencyOpCode == 0) {
            return true;
        } else if (emergencyOpCode == 1) {
            return false;
        } else {
            revert("Invalid emergency operation code");
        }
    }

    /// @dev Decodes the token transfer payload from bytes to a struct.
    /// @param payload The payload to be decoded.
    /// @return The decoded token transfer payload as a struct.
    function decodeTokenTransferPayload(bytes memory payload)
        internal
        pure
        returns (BridgeMessage.TokenTransferPayload memory)
    {
        (BridgeMessage.TokenTransferPayload memory tokenTransferPayload) =
            abi.decode(payload, (BridgeMessage.TokenTransferPayload));

        return tokenTransferPayload;
    }

    /// @dev Decodes the upgrade payload to retrieve the implementation address.
    /// @param payload The upgrade payload to be decoded.
    /// @return The implementation address extracted from the payload.
    function decodeUpgradePayload(bytes memory payload) internal pure returns (address) {
        (address implementationAddress) = abi.decode(payload, (address));
        return implementationAddress;
    }

    // note: do we want to use "upgradeToAndCall" instead?
    function _upgradeBridge(address upgradeImplementation) internal returns (bool, bytes memory) {
        // return upgradeTo(upgradeImplementation);
    }

    function _authorizeUpgrade(address newImplementation) internal override {
        // TODO: implement so only committee members can upgrade
    }

    /* ========== MODIFIERS ========== */

    /// @dev Modifier to check if the token's daily limit will not be exceeded.
    /// @param tokenId The ID of the token.
    /// @param amount The amount to be transferred.
    /// Requirements:
    /// - The token's daily limit must not be exceeded.
    modifier willNotExceedLimit(uint8 tokenId, uint256 amount) {
        require(
            !limiter.willAmountExceedLimit(tokenId, amount),
            "SuiBridge: Token's daily limit exceeded"
        );
        _;
    }
}
