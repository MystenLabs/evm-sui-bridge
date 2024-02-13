// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeTokens.sol";
import "./utils/Utils.sol";

/// @title BridgeTokens
/// @dev This contract manages the supported tokens on the bridge.
contract BridgeTokens is Ownable, IBridgeTokens {
    struct Token {
        address tokenAddress;
        uint8 suiDecimal;
    }

    mapping(uint8 tokenID => Token) public supportedTokens;

    constructor(address[] memory _tokens, uint8[] memory _decimals) Ownable(msg.sender) {
        require(_tokens.length == _decimals.length, "BridgeTokens: Invalid input");

        for (uint8 i; i < _tokens.length; i++) {
            supportedTokens[i] = Token(_tokens[i], _decimals[i]);
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

    function convertEthToSuiDecimal(uint8 tokenId, uint256 amount)
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

        amount = Utils.calculateConvertedAmount(ethDecimal, suiDecimal, amount);

        // Ensure the converted amount fits within uint64
        require(amount <= type(uint64).max, "BridgeTokens: Amount too large for uint64");

        return uint64(amount);
    }

    function convertSuiToEthDecimal(uint8 tokenId, uint64 amount)
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

        uint256 convertedAmount = Utils.calculateConvertedAmount(ethDecimal, suiDecimal, amount);

        return convertedAmount;
    }

    /// @dev Add a new supported token
    /// @param tokenId The ID of the token
    /// @param tokenAddress The address of the token
    function updateToken(uint8 tokenId, address tokenAddress, uint8 suiDecimal)
        external
        onlyOwner
    {
        supportedTokens[tokenId] = Token(tokenAddress, suiDecimal);
    }

    /// @dev Remove a supported token
    /// @param tokenId The ID of the token
    function removeToken(uint8 tokenId) external onlyOwner {
        delete supportedTokens[tokenId];
    }

    modifier tokenSupported(uint8 tokenId) {
        require(isTokenSupported(tokenId), "BridgeTokens: Unsupported token");
        _;
    }
}
