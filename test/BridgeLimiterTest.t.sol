// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BridgeBaseTest.t.sol";

contract BridgeVaultTest is BridgeBaseTest {
    BridgeLimiter public mockLimiter;

    function setUp() public {
        uint256[] memory _dailyBridgeLimits = new uint256[](4);
        _dailyBridgeLimits[0] = 100;
        _dailyBridgeLimits[1] = 200;
        _dailyBridgeLimits[2] = 300;
        _dailyBridgeLimits[3] = 400;

        mockLimiter = new BridgeLimiter(block.timestamp + 1 days, _dailyBridgeLimits);
    }

    function testAmountWillExceedLimit() public {
        uint256 amount = 100;
        uint8 tokenId = 1;
        assertFalse(mockLimiter.willAmountExceedLimit(tokenId, amount));
        mockLimiter.updateDailyAmountBridged(tokenId, amount);
        assertTrue(mockLimiter.willAmountExceedLimit(tokenId, amount));
    }

    function testGetDailyAmountBridgedBeforeReset() public {
        uint8 tokenId = 1;
        uint256 amount = 100;
        mockLimiter.updateDailyAmountBridged(tokenId, amount);
        assertEq(mockLimiter.getDailyAmountBridged(tokenId), amount);
    }

    function testGetDailyAmountBridgedAfterReset() public {
        uint8 tokenId = 1;
        uint256 amount = 100;
        mockLimiter.updateDailyAmountBridged(tokenId, amount);
        skip(1 days + 1);
        assertEq(mockLimiter.getDailyAmountBridged(tokenId), 0);
    }

    function testResetTimestampBeforeReset() public {
        uint256 nextResetTimestamp = mockLimiter.resetTimestamp();
        assertEq(nextResetTimestamp, block.timestamp + 1 days);
    }

    function testResetTimestampAfterReset() public {
        uint256 start = block.timestamp;
        // skip time by 1.5 days
        skip(1 days + 1 days / 2);
        uint256 nextResetTimestamp = mockLimiter.resetTimestamp();
        assertEq(nextResetTimestamp, start + 2 days);
    }

    function testUpdateDailyAmountBridgedBeforeReset() public {
        uint8 tokenId = 1;
        uint256 amount = 100;
        mockLimiter.updateDailyAmountBridged(tokenId, amount);
        assertEq(mockLimiter.getDailyAmountBridged(tokenId), amount);
    }

    function testUpdateDailyAmountBridgedAfterReset() public {
        uint8 tokenId = 1;
        uint256 amount = 100;
        mockLimiter.updateDailyAmountBridged(tokenId, amount);
        skip(1 days + 1);
        mockLimiter.updateDailyAmountBridged(tokenId, 50);
        assertEq(mockLimiter.getDailyAmountBridged(tokenId), 50);
    }
}
