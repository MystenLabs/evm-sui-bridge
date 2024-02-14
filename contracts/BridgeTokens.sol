// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeTokens.sol";

/// @title BridgeTokens
/// @notice This contract manages the supported tokens of the SuiBridge. It enables the contract owner
/// (intended to be the SuiBridge contract) to add and remove supported tokens. It also provides functions
/// to convert token amounts to Sui decimal adjusted amounts and vice versa.
contract BridgeTokens is Ownable, IBridgeTokens {
    /* ========== STATE VARIABLES ========== */

    mapping(uint8 tokenID => Token) public supportedTokens;

    /* ========== CONSTRUCTOR ========== */

    /// @notice Constructor function for the BridgeTokens contract.
    /// @dev the provided arrays must have the same length.
    /// @param _supportedTokens The addresses of the supported tokens.
    /// @param _suiDecimals The sui decimal places of the supported tokens.
    constructor(address[] memory _supportedTokens, uint8[] memory _suiDecimals)
        Ownable(msg.sender)
    {
        require(_supportedTokens.length == _suiDecimals.length, "BridgeTokens: Invalid input");

        for (uint8 i; i < _supportedTokens.length; i++) {
            supportedTokens[i] = Token(_supportedTokens[i], _suiDecimals[i]);
        }
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @notice Returns the address of the token with the given ID.
    /// @param tokenID The ID of the token.
    /// @return address of the provided token.
    function getAddress(uint8 tokenID) public view override returns (address) {
        return supportedTokens[tokenID].tokenAddress;
    }

    /// @notice Returns the sui decimal places of the token with the given ID.
    /// @param tokenID The ID of the token.
    /// @return amount of sui decimal places of the provided token.
    function getSuiDecimal(uint8 tokenID) public view override returns (uint8) {
        return supportedTokens[tokenID].suiDecimal;
    }

    /// @notice Returns the supported status of the token with the given ID.
    /// @param tokenID The ID of the token.
    /// @return true if the token is supported, false otherwise.
    function isTokenSupported(uint8 tokenID) public view override returns (bool) {
        return supportedTokens[tokenID].tokenAddress != address(0);
    }

    /// @notice Converts the provided token amount to the Sui decimal adjusted amount.
    /// @param tokenID The ID of the token to convert.
    /// @param amount The ERC20 amount of the tokens to convert to Sui.
    /// @return Sui converted amount.
    function convertERC20ToSuiDecimal(uint8 tokenID, uint256 amount)
        public
        view
        override
        tokenSupported(tokenID)
        returns (uint64)
    {
        uint8 ethDecimal = IERC20Metadata(getAddress(tokenID)).decimals();
        uint8 suiDecimal = getSuiDecimal(tokenID);

        if (ethDecimal == suiDecimal) {
            // Ensure converted amount fits within uint64
            require(amount <= type(uint64).max, "BridgeTokens: Amount too large for uint64");
            return uint64(amount);
        }

        if (ethDecimal > suiDecimal) {
            // Difference in decimal places
            uint256 factor = 10 ** (ethDecimal - suiDecimal);
            amount = amount / factor;
        } else {
            // Difference in decimal places
            uint256 factor = 10 ** (suiDecimal - ethDecimal);
            amount = amount * factor;
        }

        // Ensure the converted amount fits within uint64
        require(amount <= type(uint64).max, "BridgeTokens: Amount too large for uint64");

        return uint64(amount);
    }

    /// @notice Converts the provided Sui decimal adjusted amount to the ERC20 token amount.
    /// @param tokenID The ID of the token to convert.
    /// @param amount The Sui amount of the tokens to convert to ERC20.
    /// @return ERC20 converted amount.
    function convertSuiToERC20Decimal(uint8 tokenID, uint64 amount)
        public
        view
        override
        tokenSupported(tokenID)
        returns (uint256)
    {
        uint8 ethDecimal = IERC20Metadata(getAddress(tokenID)).decimals();
        uint8 suiDecimal = getSuiDecimal(tokenID);

        if (suiDecimal == ethDecimal) {
            return uint256(amount);
        }

        uint256 convertedAmount;
        if (ethDecimal > suiDecimal) {
            // Difference in decimal places
            uint256 factor = 10 ** (ethDecimal - suiDecimal);
            convertedAmount = amount * factor;
        } else {
            // Difference in decimal places
            uint256 factor = 10 ** (suiDecimal - ethDecimal);
            convertedAmount = amount / factor;
        }

        return convertedAmount;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @notice Enables the contract owner (intended to be the SuiBridge contract) to add a new supported token.
    /// @param tokenAddress The address of the token to add.
    /// @param suiDecimal The Sui decimal places of the token.
    function updateToken(uint8 tokenID, address tokenAddress, uint8 suiDecimal)
        external
        onlyOwner
    {
        supportedTokens[tokenID] = Token(tokenAddress, suiDecimal);
    }

    /// @notice Enables the contract owner (intended to be the SuiBridge contract) to remove a supported token.
    /// @param tokenID The ID of the token to remove.
    function removeToken(uint8 tokenID) external onlyOwner {
        delete supportedTokens[tokenID];
    }

    /* ========== MODIFIERS ========== */

    /// @notice Requires the given token to be supported.
    /// @param tokenID The ID of the token to check.
    modifier tokenSupported(uint8 tokenID) {
        require(isTokenSupported(tokenID), "BridgeTokens: Unsupported token");
        _;
    }
}
