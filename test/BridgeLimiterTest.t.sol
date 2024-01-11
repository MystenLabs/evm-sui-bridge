// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BridgeBaseTest.t.sol";

contract BridgeLimiterTest is BridgeBaseTest {
    BridgeLimiter public mockLimiter;

    function setUp() public {
        uint256[] memory _dailyBridgeLimits = new uint256[](4);
        _dailyBridgeLimits[0] = 100;
        _dailyBridgeLimits[1] = 200;
        _dailyBridgeLimits[2] = 300;
        _dailyBridgeLimits[3] = 400;

        skip(2 days);
        mockLimiter = new BridgeLimiter(_dailyBridgeLimits);
        // // warp to next nearest hour start
        // vm.warp(mockLimiter.getNextHourTimestamp());
    }

    function testBridgeLimiterInitialization() public {
        assertEq(mockLimiter.rollingTokenLimits(0), 100);
        assertEq(mockLimiter.rollingTokenLimits(1), 200);
        assertEq(mockLimiter.rollingTokenLimits(2), 300);
        assertEq(mockLimiter.rollingTokenLimits(3), 400);
        assertEq(mockLimiter.oldestHourTimestamp(), uint32(block.timestamp / 1 hours));
    }

    function testCalculateWindowLimit() public {
        uint8 tokenId = 1;
        mockLimiter.updateHourlyTransfers(tokenId, 10);
        skip(1 hours);
        mockLimiter.updateHourlyTransfers(tokenId, 20);
        skip(1 hours);
        uint256 actual = mockLimiter.calculateWindowAmount(tokenId);
        assertEq(actual, 30);
        skip(22 hours);
        actual = mockLimiter.calculateWindowAmount(tokenId);
        assertEq(actual, 20);
        skip(59 minutes);
        actual = mockLimiter.calculateWindowAmount(tokenId);
        assertEq(actual, 20);
        skip(1 minutes);
        actual = mockLimiter.calculateWindowAmount(tokenId);
        assertEq(actual, 0);
    }

    function testAmountWillExceedLimit() public {
        uint256 amount = 101;
        uint8 tokenId = 1;
        assertFalse(mockLimiter.willAmountExceedLimit(tokenId, amount));
        mockLimiter.updateHourlyTransfers(tokenId, amount);
        assertTrue(mockLimiter.willAmountExceedLimit(tokenId, amount));
        assertFalse(mockLimiter.willAmountExceedLimit(tokenId, amount - 2));
    }

    function testUpdateHourlyTransfersGarbageCollection() public {
        uint8 tokenId = 1;
        uint256 amount = 10;
        uint32 hourToDelete = uint32(block.timestamp / 1 hours);
        mockLimiter.updateHourlyTransfers(tokenId, amount);
        uint256 deleteAmount = mockLimiter.hourlyTransfers(tokenId, hourToDelete);
        assertEq(deleteAmount, amount);
        skip(25 hours);
        mockLimiter.updateHourlyTransfers(tokenId, amount);
        deleteAmount = mockLimiter.hourlyTransfers(tokenId, hourToDelete);
        assertEq(deleteAmount, 0);
    }

    function testGarbageCollectHourlyTransfers() public {
        uint8 tokenId = 1;
        uint256 amount = 10;
        uint32 startingHour = uint32(block.timestamp / 1 hours);
        // create many transfer updates across hours
        for (uint256 i = 0; i < 20; i++) {
            mockLimiter.updateHourlyTransfers(tokenId, amount);
            skip(1 hours);
        }
        skip(50 hours);
        // garbage collect the first 10 hours
        uint32 startHour = startingHour;
        uint32 endHour = startingHour + 10;
        assertEq(mockLimiter.oldestHourTimestamp(), startingHour);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(mockLimiter.hourlyTransfers(tokenId, uint32(startingHour + i)), amount);
        }
        mockLimiter.garbageCollectHourlyTransfers(tokenId, startHour, endHour);
        assertEq(mockLimiter.oldestHourTimestamp(), startingHour + 11);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(mockLimiter.hourlyTransfers(tokenId, uint32(startingHour + i)), 0);
        }
    }
}
