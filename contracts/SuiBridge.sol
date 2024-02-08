// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./utils/CommitteeUpgradeable.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/IBridgeLimiter.sol";
import "./interfaces/ISuiBridge.sol";
import "./interfaces/IBridgeTokens.sol";
import "./BridgeCommittee.sol";

/// @title SuiBridge
/// @dev This contract implements a bridge between Ethereum and another blockchain.
/// It allows users to transfer tokens and ETH between the two blockchains. The bridge supports
/// multiple tokens and implements various security measures such as message verification,
/// stake requirements, and upgradeability.
contract SuiBridge is ISuiBridge, CommitteeUpgradeable, PausableUpgradeable {
    /* ========== STATE VARIABLES ========== */

    IBridgeVault public vault;
    IBridgeLimiter public limiter;
    IBridgeTokens public tokens;
    IWETH9 public weth9;
    // message nonce => processed
    mapping(uint64 => bool) public messageProcessed;
    mapping(uint8 chainId => bool isSupported) public supportedChainIDs;
    
    modifier isTargetChainSupported(uint8 targetChainID) {
        require(
            supportedChainIDs[targetChainID],
            "SuiBridge: Target chain not supported"
        );
        _;
    }
    /* ========== INITIALIZER ========== */

    /// @dev Initializes the SuiBridge contract with the provided parameters.
    /// @param _committee The address of the committee contract.
    /// @param _tokens The address of the bridge tokens contract.
    /// @param _vault The address of the bridge vault contract.
    /// @param _limiter The address of the bridge limiter contract.
    /// @param _weth9 The address of the WETH9 contract.
    function initialize(
        address _committee,
        address _tokens,
        address _vault,
        address _limiter,
        address _weth9,
        uint8[] memory _supportedChainIDs
    ) external initializer {
        __CommitteeUpgradeable_init(_committee);
        __Pausable_init();
        tokens = IBridgeTokens(_tokens);
        vault = IBridgeVault(_vault);
        limiter = IBridgeLimiter(_limiter);
        weth9 = IWETH9(_weth9);

        for (uint8 i = 0; i < _supportedChainIDs.length; i++) {
            // require(_supportedChainIDs[i] != BridgeCommittee.chainID, "SuiBridge: Cannot support self");
            require(_supportedChainIDs[i] == BridgeMessage.SUI || 
                    _supportedChainIDs[i] == BridgeMessage.BTC || 
                    _supportedChainIDs[i] == BridgeMessage.USDC || 
                    _supportedChainIDs[i] == BridgeMessage.USDT, 
                    "SuiBridge: Cannot support chain");
            supportedChainIDs[_supportedChainIDs[i]] = true;
        }
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @dev Transfers tokens with signatures.
    /// @param signatures The array of signatures.
    /// @param message The BridgeMessage containing the transfer details.
    function transferTokensWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.TOKEN_TRANSFER)
        isTargetChainSupported(message.chainID)
    {
        // verify that message has not been processed
        require(!messageProcessed[message.nonce], "SuiBridge: Message already processed");

        BridgeMessage.TokenTransferPayload memory tokenTransferPayload =
            BridgeMessage.decodeTokenTransferPayload(message.payload);

        // require(tokenTransferPayload.targetChain == BridgeCommittee.chainID());

        address tokenAddress = tokens.getAddress(tokenTransferPayload.tokenId);
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
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.EMERGENCY_OP)
    {
        // decode the emergency op message
        bool isFreezing = BridgeMessage.decodeEmergencyOpPayload(message.payload);

        if (isFreezing) _pause();
        else _unpause();
    }

    /// @dev Bridges tokens from the current chain to the Sui chain.
    /// @param tokenId The ID of the token to be bridged.
    /// @param amount The amount of tokens to be bridged.
    /// @param targetAddress The address on the Sui chain where the tokens will be sent.
    /// @param destinationChainID The ID of the destination chain.
    function bridgeERC20(
        uint8 tokenId,
        uint256 amount,
        bytes memory targetAddress,
        uint8 destinationChainID
    ) external whenNotPaused nonReentrant isTargetChainSupported(destinationChainID) {

        // Check that the token address is supported (but not sui yet)
        require(
            tokenId > BridgeMessage.SUI && tokenId <= BridgeMessage.USDT,
            "SuiBridge: Unsupported token"
        );

        address tokenAddress = tokens.getAddress(tokenId);

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
            committee.chainID(),
            nonces[BridgeMessage.TOKEN_TRANSFER],
            destinationChainID,
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
    /// @param destinationChainID The ID of the destination chain.
    function bridgeETH(bytes memory targetAddress, uint8 destinationChainID)
        external
        payable
        whenNotPaused
        nonReentrant
        isTargetChainSupported(destinationChainID)
    {
        uint256 amount = msg.value;

        // Wrap ETH
        weth9.deposit{value: amount}();

        // Transfer the wrapped ETH back to caller
        weth9.transfer(address(vault), amount);

        // Adjust the amount to log.
        uint64 suiAdjustedAmount = adjustDecimalsForSuiToken(BridgeMessage.ETH, amount, 18);
        emit TokensBridgedToSui(
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

    /* ========== VIEW FUNCTIONS ========== */

    // Adjust ERC20 amount to Sui token amount to cover the decimal differences
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

    // Adjust Sui token amount to ERC20 amount to cover the decimal differences
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
    function getDecimalOnSui(uint8 tokenId) private pure returns (uint8) {
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
        revert("SuiBridge: TokenId does not have Sui decimal set");
    }

    /// @dev Transfers tokens from the vault to a target address.
    /// @param tokenId The ID of the token being transferred.
    /// @param targetAddress The address to which the tokens are being transferred.
    /// @param amount The amount of tokens being transferred.
    function _transferTokensFromVault(uint8 tokenId, address targetAddress, uint256 amount)
        private
        whenNotPaused
        limitNotExceeded(tokenId, amount)
    {
        address tokenAddress = tokens.getAddress(tokenId);

        // Check that the token address is supported
        require(tokenAddress != address(0), "SuiBridge: Unsupported token");

        // transfer eth if token type is eth
        if (tokenId == BridgeMessage.ETH) {
            vault.transferETH(payable(targetAddress), amount);
        } else {
            // transfer tokens from vault to target address
            vault.transferERC20(tokenAddress, targetAddress, amount);
        }

        // update amount bridged
        limiter.updateBridgeTransfers(tokenId, amount);
    }

    /* ========== MODIFIERS ========== */

    /// @dev Checks that the amount being transferred does not exceed the limit.
    /// @param tokenId The ID of the token being transferred.
    /// @param amount The amount of tokens being transferred.
    modifier limitNotExceeded(uint8 tokenId, uint256 amount) {
        require(
            !limiter.willAmountExceedLimit(tokenId, amount),
            "SuiBridge: Amount exceeds bridge limit"
        );
        _;
    }
}
