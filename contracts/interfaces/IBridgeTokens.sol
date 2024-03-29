// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridgeTokens {
    function getAddress(uint8 tokenId) external view returns (address);

    function getSuiDecimal(uint8 tokenId) external view returns (uint8);

    function convertERC20ToSuiDecimal(uint8 tokenId, uint256 originalAmount)
        external
        view
        returns (uint64);

    function convertSuiToERC20Decimal(uint8 tokenId, uint64 originalAmount)
        external
        view
        returns (uint256);

    function isTokenSupported(uint8 tokenId) external view returns (bool);
}
