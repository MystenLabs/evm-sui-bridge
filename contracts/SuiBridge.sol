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

contract SuiBridge is ISuiBridge, CommitteeUpgradeable, PausableUpgradeable {
    /* ========== STATE VARIABLES ========== */

    IBridgeVault public vault;
    IBridgeLimiter public limiter;
    IBridgeTokens public tokens;
    IWETH9 public weth9;
    // message nonce => processed
    mapping(uint64 => bool) public messageProcessed;
    uint8 public chainID;

    /* ========== INITIALIZER ========== */

    function initialize(
        address _committee,
        address _tokens,
        address _vault,
        address _limiter,
        address _weth9,
        uint8 _chainID
    ) external initializer {
        __CommitteeUpgradeable_init(_committee);
        __Pausable_init();
        tokens = IBridgeTokens(_tokens);
        vault = IBridgeVault(_vault);
        limiter = IBridgeLimiter(_limiter);
        weth9 = IWETH9(_weth9);
        chainID = _chainID;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function transferTokensWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external nonReentrant verifySignatures(message, signatures, BridgeMessage.TOKEN_TRANSFER) {
        // verify that message has not been processed
        require(!messageProcessed[message.nonce], "SuiBridge: Message already processed");

        BridgeMessage.TokenTransferPayload memory tokenTransferPayload =
            BridgeMessage.decodeTokenTransferPayload(message.payload);

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

    function executeEmergencyOpWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    ) external nonReentrant verifySignatures(message, signatures, BridgeMessage.EMERGENCY_OP) {
        // decode the emergency op message
        bool isFreezing = BridgeMessage.decodeEmergencyOpPayload(message.payload);

        if (isFreezing) _pause();
        else _unpause();
    }

    function bridgeToSui(
        uint8 tokenId,
        uint256 amount,
        bytes memory targetAddress,
        uint8 destinationChainID
    ) external whenNotPaused nonReentrant {
        // TODO: add checks for destination chain ID. Disallow invalid values

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
            chainID,
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

    function bridgeETHToSui(bytes memory targetAddress, uint8 destinationChainID)
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
            chainID,
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

    // TODO: garbage collect messageProcessed with design from notion (add watermark concept)

    /* ========== VIEW FUNCTIONS ========== */

    // Adjust ERC20 amount to Sui token amount to cover the decimal differences
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
        revert("SuiBridge: TokenId does not have Sui decimal set");
    }

    function _transferTokensFromVault(uint8 tokenId, address targetAddress, uint256 amount)
        internal
        whenNotPaused
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
}
