// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BridgeBaseTest.t.sol";

contract BridgeLimiterTest is BridgeBaseTest {
    function setUp() public {
        setUpBridgeTest();
        // warp to next nearest hour start
        vm.warp(block.timestamp - (block.timestamp % 1 hours));
    }

    function testBridgeLimiterInitialization() public {
        assertEq(limiter.assetPrices(0), SUI_PRICE);
        assertEq(limiter.assetPrices(1), BTC_PRICE);
        assertEq(limiter.assetPrices(2), ETH_PRICE);
        assertEq(limiter.assetPrices(3), USDC_PRICE);
        assertEq(limiter.oldestHourTimestamp(), uint32(block.timestamp / 1 hours));
        assertEq(limiter.totalLimit(), totalLimit);
    }

    function testCalculateAmountInUSD() public {
        uint8 tokenId = 1; // wBTC
        uint256 wBTCAmount = 100000000; // wBTC has 8 decimals
        uint256 actual = limiter.calculateAmountInUSD(tokenId, wBTCAmount);
        assertEq(actual, BTC_PRICE);
        tokenId = 2;
        uint256 ethAmount = 1 ether;
        actual = limiter.calculateAmountInUSD(tokenId, ethAmount);
        assertEq(actual, ETH_PRICE);
        tokenId = 3;
        uint256 usdcAmount = 1000000; // USDC has 6 decimals
        actual = limiter.calculateAmountInUSD(tokenId, usdcAmount);
        assertEq(actual, USDC_PRICE);
    }

    function testCalculateWindowLimit() public {
        changePrank(address(bridge));
        uint8 tokenId = 3;
        uint256 amount = 1000000; // USDC has 6 decimals
        limiter.updateBridgeTransfers(tokenId, amount);
        skip(1 hours);
        limiter.updateBridgeTransfers(tokenId, 2 * amount);
        skip(1 hours);
        uint256 actual = limiter.calculateWindowAmount();
        assertEq(actual, 30000);
        skip(22 hours);
        actual = limiter.calculateWindowAmount();
        assertEq(actual, 20000);
        skip(59 minutes);
        actual = limiter.calculateWindowAmount();
        assertEq(actual, 20000);
        skip(1 minutes);
        actual = limiter.calculateWindowAmount();
        assertEq(actual, 0);
    }

    function testAmountWillExceedLimit() public {
        changePrank(address(bridge));
        uint8 tokenId = 3;
        uint256 amount = 999999 * 1000000; // USDC has 6 decimals
        assertFalse(limiter.willAmountExceedLimit(tokenId, amount));
        limiter.updateBridgeTransfers(tokenId, amount);
        assertTrue(limiter.willAmountExceedLimit(tokenId, 2000000));
        assertFalse(limiter.willAmountExceedLimit(tokenId, 1000000));
    }

    function testUpdateBridgeTransfer() public {
        changePrank(address(bridge));
        uint8 tokenId = 1;
        uint256 amount = 100000000; // wBTC has 8 decimals
        limiter.updateBridgeTransfers(tokenId, amount);
        tokenId = 2;
        amount = 1 ether;
        limiter.updateBridgeTransfers(tokenId, amount);
        tokenId = 3;
        amount = 1000000; // USDC has 6 decimals
        limiter.updateBridgeTransfers(tokenId, amount);
        assertEq(
            limiter.hourlyTransferAmount(uint32(block.timestamp / 1 hours)),
            BTC_PRICE + ETH_PRICE + USDC_PRICE
        );
    }

    function testUpdateBridgeTransfersGarbageCollection() public {
        changePrank(address(bridge));
        uint8 tokenId = 1;
        uint256 amount = 100000000; // wBTC has 8 decimals
        uint32 hourToDelete = uint32(block.timestamp / 1 hours);
        limiter.updateBridgeTransfers(tokenId, amount);
        uint256 deleteAmount = limiter.hourlyTransferAmount(hourToDelete);
        assertEq(deleteAmount, BTC_PRICE);
        skip(25 hours);
        limiter.updateBridgeTransfers(tokenId, amount);
        deleteAmount = limiter.hourlyTransferAmount(hourToDelete);
        assertEq(deleteAmount, 0);
    }

    function testGarbageCollectHourlyTransferAmount() public {
        changePrank(address(bridge));
        uint8 tokenId = 1;
        uint256 amount = 100000000; // wBTC has 8 decimals
        uint32 startingHour = uint32(block.timestamp / 1 hours);
        // create many transfer updates across hours
        for (uint256 i = 0; i < 20; i++) {
            limiter.updateBridgeTransfers(tokenId, amount);
            skip(1 hours);
        }
        skip(50 hours);
        // garbage collect the first 10 hours
        uint32 startHour = startingHour;
        uint32 endHour = startingHour + 10;
        assertEq(limiter.oldestHourTimestamp(), startingHour);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(limiter.hourlyTransferAmount(uint32(startingHour + i)), BTC_PRICE);
        }
        limiter.garbageCollectHourlyTransferAmount(startHour, endHour);
        assertEq(limiter.oldestHourTimestamp(), startingHour + 11);
        for (uint256 i = 0; i < 10; i++) {
            assertEq(limiter.hourlyTransferAmount(uint32(startingHour + i)), 0);
        }
    }
}
