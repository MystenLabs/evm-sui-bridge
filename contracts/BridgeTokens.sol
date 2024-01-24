// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeTokens.sol";

/// @title BridgeTokens
/// @dev This contract manages the supported tokens on the bridge.
contract BridgeTokens is Ownable, IBridgeTokens {
    // token id => token address
    mapping(uint8 tokenId => address tokenAddress) public supportedTokens;

    /// @dev Constructor function
    /// @param _supportedTokens An array of addresses representing the supported tokens
    constructor(address[] memory _supportedTokens) Ownable() {
        for (uint8 i = 0; i < _supportedTokens.length; i++) {
            // skip 0 for SUI
            supportedTokens[i + 1] = _supportedTokens[i];
        }
    }

    /// @dev Get the address of a supported token
    /// @param tokenId The ID of the token
    /// @return The address of the token
    function getAddress(uint8 tokenId) external view override returns (address) {
        return supportedTokens[tokenId];
    }

    /// @dev Add a new supported token
    /// @param tokenId The ID of the token
    /// @param tokenAddress The address of the token
    function addToken(uint8 tokenId, address tokenAddress) external onlyOwner {
        supportedTokens[tokenId] = tokenAddress;
    }

    /// @dev Remove a supported token
    /// @param tokenId The ID of the token
    function removeToken(uint8 tokenId) external onlyOwner {
        delete supportedTokens[tokenId];
    }
}
