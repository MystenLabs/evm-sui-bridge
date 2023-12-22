pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/ISuiBridge.sol";

contract SuiBridge is
    ISuiBridge,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;

    IBridgeVault public vault;
    IWETH9 public weth9;

    // message type => nonce
    mapping(uint256 => uint256) public nonces;

    // TODO: combine message types into one spot somehow?
    uint256 public constant TOKEN_TRANSFER = 0;
    uint256 public constant EMERGENCY_OP = 2;

    // tokenIds
    uint256 public constant SUI = 0;
    uint256 public constant BTC = 1;
    uint256 public constant ETH = 2;
    uint256 public constant USDC = 3;
    uint256 public constant USDT = 4;

    address[] public supportedTokens;

    function initialize(address[] memory _supportedTokens, address _vault, address _weth9)
        external
        initializer
    {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        supportedTokens = _supportedTokens;
        vault = IBridgeVault(_vault);
        weth9 = IWETH9(_weth9);
    }

    function submitMessage(bytes memory message) external override onlyOwner nonReentrant {
        // Decode the message
        (uint256 nonce, uint256 version, uint256 messageType, bytes memory payload) =
            abi.decode(message, (uint256, uint256, uint256, bytes));

        // Decode the payload depending on the message type
        if (messageType == TOKEN_TRANSFER) {
            _processTokenTransferMessage(payload);
        } else if (messageType == EMERGENCY_OP) {
            _processEmergencyOpMessage(payload);
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

    function bridgeToSui(
        uint256 tokenId,
        uint256 amount,
        bytes memory targetAddress,
        uint256 destinationChainId
    ) public whenNotPaused {
        // Round amount down to nearest whole 8 decimal place (Sui only has 8 decimal places)
        amount = amount.div(10 ** 10).mul(10 ** 10);

        // Check that the token address is supported (but not sui yet)
        require(tokenId > SUI && tokenId <= USDT, "SuiBridge: Unsupported token");

        address tokenAddress = supportedTokens[tokenId - 1];

        // check that the bridge contract has allowance to transfer the tokens
        require(
            IERC20(tokenAddress).allowance(msg.sender, address(this)) >= amount,
            "SuiBridge: Insufficient allowance"
        );

        // Transfer the tokens from the contract to the vault
        IERC20(tokenAddress).transferFrom(msg.sender, address(vault), amount);

        // increment token transfer nonce
        nonces[TOKEN_TRANSFER]++;

        emit TokensBridgedToSui(
            tokenId, amount, targetAddress, destinationChainId, nonces[TOKEN_TRANSFER]
            );
    }

    function bridgeETHToSui(bytes memory targetAddress, uint256 destinationChainId)
        external
        payable
        whenNotPaused
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
        nonces[TOKEN_TRANSFER]++;

        emit TokensBridgedToSui(
            ETH, amount, targetAddress, destinationChainId, nonces[TOKEN_TRANSFER]
            );
    }

    function _processTokenTransferMessage(bytes memory message) internal whenNotPaused {
        // Decode the message
        // TODO: this is causing a "Stack Too Deep" error. Need to refactor
        // https://soliditydeveloper.com/stacktoodeep

        // Decode the message using the decodeMessage function
        Message memory decodedMessage = decodeMessage(message);

        address tokenAddress = supportedTokens[decodedMessage.tokenType];

        // Check that the token address is supported
        require(tokenAddress != address(0), "SuiBridge: Unsupported token");

        // transfer tokens from vault to target address
        vault.transferERC20(tokenAddress, decodedMessage.targetAddress, decodedMessage.amount);

        // increment token transfer nonce
        nonces[TOKEN_TRANSFER]++;
    }

    // Define a function to decode the message bytes into a Message struct
    function decodeMessage(bytes memory message) internal pure returns (Message memory) {
        // Create a scope for decoding the message
        {
            (
                uint8 messageType,
                uint8 version,
                uint64 nonce,
                uint8 sourceChain,
                uint8 sourceChainTxIdLength,
                uint8 sourceChainTxId,
                uint8 sourceChainEventIndex,
                uint8 senderAddressLength,
                bytes memory senderAddress,
                uint8 targetChain,
                uint8 targetAddressLength,
                address targetAddress,
                uint8 tokenType,
                uint64 amount
            ) = abi.decode(
                message,
                (
                    uint8,
                    uint8,
                    uint64,
                    uint8,
                    uint8,
                    uint8,
                    uint8,
                    uint8,
                    bytes,
                    uint8,
                    uint8,
                    address,
                    uint8,
                    uint64
                )
            );

            // Return a Message struct with the decoded values
            return
                Message(
                    messageType,
                    version,
                    nonce,
                    sourceChain,
                    sourceChainTxIdLength,
                    sourceChainTxId,
                    sourceChainEventIndex,
                    senderAddressLength,
                    senderAddress,
                    targetChain,
                    targetAddressLength,
                    targetAddress,
                    tokenType,
                    amount
                );
        }
    }

    function _processEmergencyOpMessage(bytes memory message) internal {
        (uint256 emergencyOpCode) = abi.decode(message, (uint256));

        if (emergencyOpCode == 0) _freezeVault();
        else if (emergencyOpCode == 1) _unfreezeVault();
        else revert("SuiBridge: Invalid op code");

        // increment emergency op nonce
        nonces[EMERGENCY_OP]++;
    }

    function _freezeVault() internal {
        _pause();
    }

    function _unfreezeVault() internal {
        _unpause();
    }
}
