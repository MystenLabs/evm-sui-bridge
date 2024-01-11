// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeLimiter.sol";
import "forge-std/Test.sol";

contract BridgeLimiter is IBridgeLimiter, Ownable {
    /* ========== STATE VARIABLES ========== */

    // token id => hour timestamp => total amount bridged (on a given hour)
    mapping(uint8 => mapping(uint32 => uint256)) public hourlyTransfers;
    // token id => maximum amount bridged within the rolling window
    mapping(uint8 => uint256) public rollingTokenLimits;
    uint32 public oldestHourTimestamp;

    /* ========== INITIALIZER ========== */

    constructor(uint256[] memory _rollingTokenLimits) {
        for (uint8 i = 0; i < _rollingTokenLimits.length; i++) {
            rollingTokenLimits[i] = _rollingTokenLimits[i];
        }
        oldestHourTimestamp = uint32(block.timestamp / 1 hours);
    }

    /* ========== VIEW FUNCTIONS ========== */

    function willAmountExceedLimit(uint8 tokenId, uint256 amount)
        public
        view
        override
        returns (bool)
    {
        uint256 totalTransferred = calculateWindowAmount(tokenId);
        return totalTransferred + amount > rollingTokenLimits[tokenId];
    }

    function calculateWindowAmount(uint8 tokenId) public view returns (uint256 total) {
        uint32 currentHour = uint32(block.timestamp / 1 hours);
        // aggregate the last 24 hours
        for (uint32 i = 0; i < 24; i++) {
            total += hourlyTransfers[tokenId][currentHour - i];
        }
        return total;
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function updateHourlyTransfers(uint8 tokenId, uint256 amount) external override {
        require(amount > 0, "BridgeLimiter: amount must be greater than 0");
        require(
            !willAmountExceedLimit(tokenId, amount),
            "BridgeLimiter: amount exceeds rolling window limit"
        );

        uint32 currentHour = uint32(block.timestamp / 1 hours);

        // garbage collect most recently expired hour if window is moving
        if (hourlyTransfers[tokenId][currentHour] == 0 && oldestHourTimestamp < currentHour - 24) {
            garbageCollectHourlyTransfers(tokenId, currentHour - 25, currentHour - 25);
        }

        // update hourly transfers
        hourlyTransfers[tokenId][currentHour] += amount;
    }

    function garbageCollectHourlyTransfers(uint8 tokenId, uint32 startHour, uint32 endHour)
        public
        onlyOwner
    {
        uint32 windowStart = uint32(block.timestamp / 1 hours) - 24;
        require(
            startHour >= oldestHourTimestamp, "BridgeLimiter: hourTimestamp must be in the past"
        );
        require(startHour < windowStart, "BridgeLimiter: start must be before current window");
        require(endHour < windowStart, "BridgeLimiter: end must be before current window");

        for (uint32 i = startHour; i <= endHour; i++) {
            if (hourlyTransfers[tokenId][i] > 0) delete hourlyTransfers[tokenId][i];
        }

        // update oldest hour if current oldest hour was garbage collected
        if (startHour == oldestHourTimestamp) {
            oldestHourTimestamp = endHour + 1;
        }
    }
}
