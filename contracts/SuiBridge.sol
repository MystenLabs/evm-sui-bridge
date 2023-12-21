pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IWETH9.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "./interfaces/IBridgeVault.sol";
import "./interfaces/ISuiBridge.sol";

contract SuiBridge is
    ISuiBridge,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMath for uint256;

    // Define the Uniswap contract addresses
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant NONFUNGIBLE_POSITION_MANAGER = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;

    // Define the Uniswap contract interfaces
    INonfungiblePositionManager public nonfungiblePositionManager = INonfungiblePositionManager(NONFUNGIBLE_POSITION_MANAGER);
    IWETH9 public weth9 = IWETH9(WETH9);

    IBridgeVault public vault;
    mapping(address => bool) public supportedTokens;
    uint256 public constant TOKEN_TRANSFER = 0;
    uint256 public constant EMERGENCY_OP = 2;

    function initialize(address[] memory _supportedTokens, address _vault, ISwapRouter _swapRouter) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens[_supportedTokens[i]] = true;
        }

        vault = IBridgeVault(_vault);
        swapRouter = _swapRouter;
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
        // Divide by 10^10 to remove the last 10 decimals. Multiply by 10^10 to restore the 18 decimals
        // Note: still has 18 decimal places but only the first 8 can be greater than 0
        // Use SafeMath to prevent overflows and underflows
        amount = amount.div(10**10).mul(10**10);

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
        // Round amount down to nearest whole 8 decimal place (Sui only has 8 decimal places)
        // Divide by 10^10 to remove the last 10 decimals. Multiply by 10^10 to restore the 18 decimals
        // Use SafeMath to prevent overflows and underflows
        amount = amount.div(10**10).mul(10**10);

        // Wrap ETH
        // 1. Call the deposit function on the WETH contract
        // 2. Send the ETH to the WETH contract
        // 3. The WETH contract will return the same amount of WETH
        weth9.deposit{value: amount}();

    // Create a pool with ETH and the token address
    // Call the createAndInitializePoolIfNecessary function on the NonfungiblePositionManager contract
    // Pass the WETH address, the token address, the fee, and the sqrtPriceX96
    // The fee is the percentage of the pool that is collected by the liquidity providers
    // The sqrtPriceX96 is the initial price of the pool, encoded as a square root
    // For example, if the initial price is 1 ETH = 1000 tokens, the sqrtPriceX96 is sqrt(1e18 * 1e6 / 1e3) * 2^96
    // The function will return the pool address and the pool's initialized state
    (address pool, bool initialized) = nonfungiblePositionManager
        .createAndInitializePoolIfNecessary(
            WETH9,
            tokenAddress,
            3000, // fee
            79228162514264337593543950336 // sqrtPriceX96
        );

    // Bridge to Sui
    // Call the bridgeToSui function with the pool address, the target address, and the amount

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
