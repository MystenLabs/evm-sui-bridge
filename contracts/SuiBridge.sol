pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Question: Do we need also to import noreentrancy guard?
contract SuiBridge is OwnableUpgradeable, PausableUpgradeable {
    mapping(uint256 => address) public supportedTokens;

    uint256 public constant TOKEN_TRANSFER = 0;
    uint256 public constant EMERGENCY_OP = 2;

    function initialize(address[] memory _supportedTokens) external initializer {
        __Ownable_init();
        __Pausable_init();
        for (uint256 i = 0; i < _supportedTokens.length; i++) {
            supportedTokens[i] = _supportedTokens[i];
        }
    }

    function submitMessage(bytes memory message) external onlyOwner whenNotPaused {
        // TODO: DECODE MESSAGE AND CALL CORRECT FUNCTION
    }

    function decodeMessage(bytes memory message)
        internal
        view
        whenNotPaused
        returns (uint256 nonce, uint256 version, uint256 messageType, bytes memory payload)
    {
        // TODO: DECODE MESSAGE

        // Decode the message
        (nonce, version, messageType, payload) = abi.decode(
            message,
            (uint256, uint256, uint256, bytes)
        );
    }

    // TODO: function interface may need to change depending on where supportedTokens is referenced
    function _transferTokens(address tokenAddress, address targetAddress, uint256 amount, uint256 tokenEnum)
        internal
        whenNotPaused
    {
        // TODO: vault transfer

        // Check that the token address is supported
        require(supportedTokens[tokenEnum] != address(0), "Unsupported token");

        // Get the token contract instance
        IERC20 token = IERC20(supportedTokens[tokenEnum]);

        // Question: Do we also need a function to check if the token is frozen?
        // Transfer the tokens from the contract to the target address
        bool success = token.transfer(targetAddress, amount);

        // Check that the transfer was successful
        require(success, "Transfer failed");
    }

    function _freezeVault() internal {
        _pause();
    }

    function _unfreezeVault() internal {
        _unpause();
    }
}
