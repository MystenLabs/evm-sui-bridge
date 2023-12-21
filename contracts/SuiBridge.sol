pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/ISuiBridge.sol";

contract SuiBridge is
    ISuiBridge,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    IBridgeVault public vault;
    mapping(address => bool) public supportedTokens;
    uint256 public constant TOKEN_TRANSFER = 0;
    uint256 public constant EMERGENCY_OP = 2;

    function initialize(address[] memory _supportedTokens, address _vault) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens[_supportedTokens[i]] = true;
        }

        vault = IBridgeVault(_vault);
    }

    function submitMessage(bytes memory message)
        external
        override
        onlyOwner
        whenNotPaused
        nonReentrant
    {
        // Decode the message
        (uint256 nonce, uint256 version, uint256 messageType, bytes memory payload) =
            abi.decode(message, (uint256, uint256, uint256, bytes));

        // Decode the payload depending on the message type
        if (messageType == TOKEN_TRANSFER) {
            _handleTokenTransferPayload(payload);
        } else if (messageType == EMERGENCY_OP) {
            _handleEmergencyOpPayload(payload);
        } else {
            revert("Invalid message type");
        }
    }

    function transferOwnership(address newOwner)
        public
        override(ISuiBridge, OwnableUpgradeable)
        onlyOwner
    {
        OwnableUpgradeable._transferOwnership(newOwner);
    }

    // TODO: function interface may need to change depending on data needed in event
    function bridgeToSui(address tokenAddress, address targetAddress, uint256 amount) public {
        // TODO: round amount down to nearest whole 8 decimal place (Sui only has 8 decimal places)
        // note: still has 18 decimal places but only the first 8 can be greater than 0

        // Check that the token address is supported
        require(supportedTokens[tokenAddress], "Unsupported token");

        // check that the bridge contract has allowance to transfer the tokens
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "Insufficient allowance"
        );

        // Transfer the tokens from the contract to the vault
        IERC20(tokenAddress).transferFrom(msg.sender, address(vault), amount);

        emit TokensBridgedToSui(tokenAddress, targetAddress, amount);
    }

    function bridgeETHToSui(address tokenAddress, address targetAddress, uint256 amount)
        external
        payable
    {
        // TODO: round amount down to nearest whole 8 decimal place (Sui only has 8 decimal places)

        // TODO: wrap ETH
        address wETHAddress;

        bridgeToSui(wETHAddress, targetAddress, amount);
    }

    function _transferTokens(address tokenAddress, address targetAddress, uint256 amount)
        internal
        whenNotPaused
    {
        // Check that the token address is supported
        require(supportedTokens[tokenAddress], "Unsupported token");

        // Get the token contract instance
        vault.transferERC20(tokenAddress, targetAddress, amount);
    }

    function _handleTokenTransferPayload(bytes memory payload) internal {
        // Decode the payload
        (address tokenAddress, address targetAddress, uint256 amount) =
            abi.decode(payload, (address, address, uint256));

        // Transfer the tokens from the contract to the target address
        _transferTokens(tokenAddress, targetAddress, amount);
    }

    function _handleEmergencyOpPayload(bytes memory payload) internal {
        // Decode the payload
        (address tokenAddress, address targetAddress, uint256 amount) =
            abi.decode(payload, (address, address, uint256));

        // Transfer the tokens from the contract to the target address
        _transferTokens(tokenAddress, targetAddress, amount);
    }

    function _freezeVault() internal {
        _pause();
    }

    function _unfreezeVault() internal {
        _unpause();
    }
}
