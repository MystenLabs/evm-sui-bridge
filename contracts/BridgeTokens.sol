// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeTokens.sol";

/// @title BridgeTokens
/// @dev This contract manages the supported tokens on the bridge.
contract BridgeTokens is Ownable, IBridgeTokens {
    struct Token {
        address tokenAddress;
        uint8 suiDecimal;
    }

    mapping(uint8 tokenID => Token) public supportedTokens;

    /// @notice Constructor function for the BridgeTokens contract.
    /// @dev the provided arrays must have the same length.
    /// @param _supportedTokens The addresses of the supported tokens.
    constructor(address[] memory _supportedTokens) Ownable(msg.sender) {
        require(_supportedTokens.length == 4, "BridgeTokens: Invalid supported token addresses");

        uint8[] memory _suiDecimals = new uint8[](5);
        _suiDecimals[0] = 9; // SUI
        _suiDecimals[1] = 8; // wBTC
        _suiDecimals[2] = 8; // wETH
        _suiDecimals[3] = 6; // USDC
        _suiDecimals[4] = 6; // USDT

        // Add SUI as the first supported token
        supportedTokens[0] = Token(address(0), _suiDecimals[0]);

        for (uint8 i; i < _supportedTokens.length; i++) {
            supportedTokens[i + 1] = Token(_supportedTokens[i], _suiDecimals[i + 1]);
        }
    }

    function getAddress(uint8 tokenId) public view override returns (address) {
        return supportedTokens[tokenId].tokenAddress;
    }

    function getSuiDecimal(uint8 tokenId) public view override returns (uint8) {
        return supportedTokens[tokenId].suiDecimal;
    }

    function isTokenSupported(uint8 tokenId) public view override returns (bool) {
        return supportedTokens[tokenId].tokenAddress != address(0);
    }

    function convertERC20ToSuiDecimal(uint8 tokenId, uint256 amount)
        public
        view
        override
        tokenSupported(tokenId)
        returns (uint64)
    {
        uint8 ethDecimal = IERC20Metadata(getAddress(tokenId)).decimals();
        uint8 suiDecimal = getSuiDecimal(tokenId);

        if (ethDecimal == suiDecimal) {
            // Ensure the converted amount fits within uint64
            require(amount <= type(uint64).max, "BridgeTokens: Amount too large for uint64");
            return uint64(amount);
        }

        require(ethDecimal > suiDecimal, "BridgeTokens: Invalid Sui decimal");

        // Difference in decimal places
        uint256 factor = 10 ** (ethDecimal - suiDecimal);
        amount = amount / factor;

        // Ensure the converted amount fits within uint64
        require(amount <= type(uint64).max, "BridgeTokens: Amount too large for uint64");

        return uint64(amount);
    }

    function convertSuiToERC20Decimal(uint8 tokenId, uint64 amount)
        public
        view
        override
        tokenSupported(tokenId)
        returns (uint256)
    {
        uint8 ethDecimal = IERC20Metadata(getAddress(tokenId)).decimals();
        uint8 suiDecimal = getSuiDecimal(tokenId);

        if (suiDecimal == ethDecimal) {
            return uint256(amount);
        }

        require(ethDecimal > suiDecimal, "BridgeTokens: Invalid Sui decimal");

        // Difference in decimal places
        uint256 factor = 10 ** (ethDecimal - suiDecimal);
        return uint256(amount * factor);
    }

    modifier tokenSupported(uint8 tokenId) {
        require(isTokenSupported(tokenId), "BridgeTokens: Unsupported token");
        _;
    }
}
