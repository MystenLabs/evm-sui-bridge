// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/CommitteeUpgradeable.sol";
import "./interfaces/ISuiBridge.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/IBridgeLimiter.sol";
import "./interfaces/IBridgeTokens.sol";
import "./interfaces/IWETH9.sol";

/// @title SuiBridge
/// @notice This contract implements a token bridge that enables users to deposit and withdraw
/// supported tokens to and from other chains. The bridge supports the transfer of Ethereum and ERC20
/// tokens. Bridge operations are managed by a committee of Sui validators that are responsible
/// for verifying and processing bridge messages. The bridge is designed to be upgradeable and
/// can be paused in case of an emergency. The bridge also enforces limits on the amount of
/// assets that can be withdrawn to prevent abuse.
contract SuiBridge is ISuiBridge, CommitteeUpgradeable, PausableUpgradeable {
    /* ========== STATE VARIABLES ========== */

    IBridgeVault public vault;
    IBridgeLimiter public limiter;
    IBridgeTokens public tokens;
    IWETH9 public wETH;
    mapping(uint64 nonce => bool isProcessed) public isMessageProcessed;
    mapping(uint8 chainId => bool isSupported) public isChainSupported;

    /* ========== INITIALIZER ========== */

    /// @notice Initializes the SuiBridge contract with the provided parameters.
    /// @dev this function should be called directly after deployment (see OpenZeppelin upgradeable standards).
    /// @param _committee The address of the committee contract.
    /// @param _tokens The address of the bridge tokens contract.
    /// @param _vault The address of the bridge vault contract.
    /// @param _limiter The address of the bridge limiter contract.
    /// @param _wETH The address of the WETH9 contract.
    /// @param supportedChainIDs array of supported chain IDs.
    function initialize(
        address _committee,
        address _tokens,
        address _vault,
        address _limiter,
        address _wETH,
        uint8[] memory supportedChainIDs
    ) external initializer {
        __CommitteeUpgradeable_init(_committee);
        __Pausable_init();
        tokens = IBridgeTokens(_tokens);
        vault = IBridgeVault(_vault);
        limiter = IBridgeLimiter(_limiter);
        wETH = IWETH9(_wETH);

        for (uint8 i; i < supportedChainIDs.length; i++) {
            require(supportedChainIDs[i] != committee.chainID(), "SuiBridge: Cannot support self");
            isChainSupported[supportedChainIDs[i]] = true;
        }
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @notice Allows the caller to provide signatures that enable the transfer of tokens to
    /// the recipient address indicated within the message payload.
    /// @dev `message.chainID` represents the sending chain ID. Receiving chain ID needs to match
    /// this bridge's chain ID (this chain).
    /// @param signatures The array of signatures.
    /// @param message The BridgeMessage containing the transfer details.
    function transferBridgedTokensWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.TOKEN_TRANSFER)
        onlySupportedChain(message.chainID)
    {
        // verify that message has not been processed
        require(!isMessageProcessed[message.nonce], "SuiBridge: Message already processed");

        BridgeMessage.TokenTransferPayload memory tokenTransferPayload =
            BridgeMessage.decodeTokenTransferPayload(message.payload);

        // verify target chain ID is this chain ID
        require(
            tokenTransferPayload.targetChain == committee.chainID(),
            "SuiBridge: Invalid target chain"
        );

        // convert amount to ERC20 token decimals
        uint256 erc20AdjustedAmount = tokens.convertSuiToERC20Decimal(
            tokenTransferPayload.tokenID, tokenTransferPayload.amount
        );

        _transferTokensFromVault(
            tokenTransferPayload.tokenID, tokenTransferPayload.targetAddress, erc20AdjustedAmount
        );

        // mark message as processed
        isMessageProcessed[message.nonce] = true;

        emit BridgedTokensTransferred(
            message.chainID,
            message.nonce,
            tokenTransferPayload.tokenID,
            erc20AdjustedAmount,
            tokenTransferPayload.senderAddress,
            tokenTransferPayload.targetAddress
        );
    }

    /// @notice Executes an emergency operation with the provided signatures and message.
    /// @dev If the given operation is to freeze and the bridge is already frozen, the operation
    /// will revert.
    /// @param signatures The array of signatures to verify.
    /// @param message The BridgeMessage containing the details of the operation.
    function executeEmergencyOpWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.EMERGENCY_OP)
    {
        // decode the emergency op message
        bool isFreezing = BridgeMessage.decodeEmergencyOpPayload(message.payload);

        if (isFreezing) _pause();
        else _unpause();
        // pausing event emitted in 'PausableUpgradeable.sol'
    }

    /// @notice Enables the caller to deposit supported tokens to be bridged to a given
    /// destination chain.
    /// @dev The provided tokenID and destinationChainID must be supported. The caller must
    /// have approved this contract to transfer the given token.
    /// @param tokenID The ID of the token to be bridged.
    /// @param amount The amount of tokens to be bridged.
    /// @param targetAddress The address on the Sui chain where the tokens will be sent.
    /// @param destinationChainID The ID of the destination chain.
    function bridgeERC20(
        uint8 tokenID,
        uint256 amount,
        bytes memory targetAddress,
        uint8 destinationChainID
    ) external whenNotPaused nonReentrant onlySupportedChain(destinationChainID) {
        require(tokens.isTokenSupported(tokenID), "SuiBridge: Unsupported token");

        address tokenAddress = tokens.getAddress(tokenID);

        // check that the bridge contract has allowance to transfer the tokens
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "SuiBridge: Insufficient allowance"
        );

        // Transfer the tokens from the contract to the vault
        IERC20(tokenAddress).transferFrom(msg.sender, address(vault), amount);

        // Adjust the amount to emit.
        uint64 suiAdjustedAmount = tokens.convertERC20ToSuiDecimal(tokenID, amount);

        emit TokensDeposited(
            committee.chainID(),
            nonces[BridgeMessage.TOKEN_TRANSFER],
            destinationChainID,
            tokenID,
            suiAdjustedAmount,
            msg.sender,
            targetAddress
        );

        // increment token transfer nonce
        nonces[BridgeMessage.TOKEN_TRANSFER]++;
    }

    /// @notice Enables the caller to deposit Eth to be bridged to a given destination chain.
    /// @dev The provided destinationChainID must be supported.
    /// @param targetAddress The address on the destination chain where Eth will be sent.
    /// @param destinationChainID The ID of the destination chain.
    function bridgeETH(bytes memory targetAddress, uint8 destinationChainID)
        external
        payable
        whenNotPaused
        nonReentrant
        onlySupportedChain(destinationChainID)
    {
        uint256 amount = msg.value;

        // Wrap ETH
        wETH.deposit{value: amount}();

        // Transfer the wrapped ETH back to caller
        wETH.transfer(address(vault), amount);

        // Adjust the amount to emit.
        uint64 suiAdjustedAmount = tokens.convertERC20ToSuiDecimal(BridgeMessage.ETH, amount);

        emit TokensDeposited(
            committee.chainID(),
            nonces[BridgeMessage.TOKEN_TRANSFER],
            destinationChainID,
            BridgeMessage.ETH,
            suiAdjustedAmount,
            msg.sender,
            targetAddress
        );

        // increment token transfer nonce
        nonces[BridgeMessage.TOKEN_TRANSFER]++;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    /// @dev Transfers tokens from the vault to a target address.
    /// @param tokenID The ID of the token being transferred.
    /// @param targetAddress The address to which the tokens are being transferred.
    /// @param amount The amount of tokens being transferred.
    function _transferTokensFromVault(uint8 tokenID, address targetAddress, uint256 amount)
        private
        whenNotPaused
        limitNotExceeded(tokenID, amount)
    {
        address tokenAddress = tokens.getAddress(tokenID);

        // Check that the token address is supported
        require(tokenAddress != address(0), "SuiBridge: Unsupported token");

        // transfer eth if token type is eth
        if (tokenID == BridgeMessage.ETH) {
            vault.transferETH(payable(targetAddress), amount);
        } else {
            // transfer tokens from vault to target address
            vault.transferERC20(tokenAddress, targetAddress, amount);
        }

        // update amount bridged
        limiter.recordBridgeTransfers(tokenID, amount);
    }

    /* ========== MODIFIERS ========== */

    /// @dev Requires the amount being transferred does not exceed the bridge limit in
    /// the last 24 hours.
    /// @param tokenID The ID of the token being transferred.
    /// @param amount The amount of tokens being transferred.
    modifier limitNotExceeded(uint8 tokenID, uint256 amount) {
        require(
            !limiter.willAmountExceedLimit(tokenID, amount),
            "SuiBridge: Amount exceeds bridge limit"
        );
        _;
    }

    /// @dev Requires the target chain ID is supported.
    /// @param targetChainID The ID of the target chain.
    modifier onlySupportedChain(uint8 targetChainID) {
        require(isChainSupported[targetChainID], "SuiBridge: Target chain not supported");
        _;
    }
}
