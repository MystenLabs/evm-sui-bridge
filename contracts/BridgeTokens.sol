// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeTokens.sol";

contract BridgeTokens is Ownable, IBridgeTokens {
    // token id => token address
    mapping(uint8 => address) public supportedTokens;

    constructor(address[] memory _supportedTokens) Ownable() {
        for (uint8 i = 0; i < _supportedTokens.length; i++) {
            // skip 0 for SUI
            supportedTokens[i + 1] = _supportedTokens[i];
        }
    }

    function getAddress(uint8 tokenId) external view override returns (address) {
        return supportedTokens[tokenId];
    }

    function addToken(uint8 tokenId, address tokenAddress) external onlyOwner {
        supportedTokens[tokenId] = tokenAddress;
    }

    function removeToken(uint8 tokenId) external onlyOwner {
        delete supportedTokens[tokenId];
    }
}
