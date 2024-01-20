// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridgeLimiter {
    function updateBridgeTransfers(uint8 tokenId, uint256 amount) external;
}
