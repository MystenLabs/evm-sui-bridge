// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeLimiter {
    function willAmountExceedLimit(uint8 tokenId, uint256 amount) external view returns (bool);

    function updateDailyAmountBridged(uint8 tokenId, uint256 amount) external;
}
