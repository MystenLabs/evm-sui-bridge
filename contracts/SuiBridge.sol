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

    // Adjust ERC20 amount to Sui Coin amount to cover the decimal differences
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

    // Adjust Sui coin amount to ERC20 amount to cover the decimal differences
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
        revert("TokenId does not have Sui decimal set");
    }

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

    function decodeTokenTransferPayload(bytes memory payload)
        internal
        pure
        returns (BridgeMessage.TokenTransferPayload memory)
    {
        (BridgeMessage.TokenTransferPayload memory tokenTransferPayload) =
            abi.decode(payload, (BridgeMessage.TokenTransferPayload));

        return tokenTransferPayload;
    }

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

    modifier willNotExceedLimit(uint8 tokenId, uint256 amount) {
        require(
            !limiter.willAmountExceedLimit(tokenId, amount),
            "SuiBridge: Token's daily limit exceeded"
        );
        _;
    }
}
