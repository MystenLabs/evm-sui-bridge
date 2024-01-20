// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridgeTokens {
    function getAddress(uint8 tokenId) external view returns (address);
}
