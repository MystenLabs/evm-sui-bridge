pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

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

    function submitMessage(bytes memory message) external onlyOwner {
        // TODO: DECODE MESSAGE AND CALL CORRECT FUNCTION
    }

    function decodeMessage(bytes memory message)
        internal
        pure
        returns (uint256 nonce, uint256 version, uint256 messageType, bytes memory payload)
    {
        // TODO: DECODE MESSAGE
    }

    // TODO: function interface may need to change depending on where supportedTokens is referenced
    function _transferTokens(address tokenAddress, address targetAddress, uint256 amount)
        internal
    {
        // TODO: vault transfer
    }

    function _freezeVault() internal {
        _pause();
    }

    function _unfreezeVault() internal {
        _unpause();
    }
}
