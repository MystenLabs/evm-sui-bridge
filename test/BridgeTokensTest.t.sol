// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./mocks/MockTokens.sol";
import "./BridgeBaseTest.t.sol";

contract BridgeTokensTest is BridgeBaseTest {
    function setUp() public {
        setUpBridgeTest();
    }

    function testBridgeTokensInitialization() public {
        assertTrue(tokens.getAddress(1) == wBTC);
        assertTrue(tokens.getAddress(2) == wETH);
        assertTrue(tokens.getAddress(3) == USDC);
        assertTrue(tokens.getAddress(4) == USDT);
        assertEq(tokens.getSuiDecimal(0), 9);
        assertEq(tokens.getSuiDecimal(1), 8);
        assertEq(tokens.getSuiDecimal(2), 8);
        assertEq(tokens.getSuiDecimal(3), 6);
        assertEq(tokens.getSuiDecimal(4), 6);
    }

    function testGetAddress() public {
        assertEq(tokens.getAddress(1), wBTC);
    }

    function testUpdateToken() public {
        // create mock token
        address mockToken = address(new MockUSDC());
        changePrank(address(bridge));
        tokens.updateToken(6, mockToken, 8);
        assertEq(tokens.getAddress(6), mockToken);
        assertEq(tokens.getSuiDecimal(6), 8);
    }

    function testRemoveToken() public {
        changePrank(address(bridge));
        tokens.removeToken(1);
        assertEq(tokens.getAddress(1), address(0));
    }

    function testConvertEthToSuiDecimalAmountTooLargeForUint64() public {
        vm.expectRevert(bytes("BridgeTokens: Amount too large for uint64"));
        tokens.convertEthToSuiDecimal(BridgeMessage.ETH, type(uint256).max);
    }

    function testConvertEthToSuiDecimalTokenIdNotSupported() public {
        vm.expectRevert(bytes("BridgeTokens: Unsupported token"));
        tokens.convertEthToSuiDecimal(type(uint8).max, 10 ether);
    }

    function testConvertEthToSuiDecimalEthDecimalLessThanSuiDecimal() public {
        vm.startPrank(address(bridge));
        tokens.updateToken(2, wETH, 19);
        uint64 suiAmount = tokens.convertEthToSuiDecimal(2, 100);
        assertEq(suiAmount, 1000);
    }

    function testConvertSuiToEthDecimalEthDecimalGreaterThanSuiDecimal() public {
        vm.startPrank(address(bridge));
        tokens.updateToken(2, wETH, 19);
        uint256 suiAmount = tokens.convertSuiToEthDecimal(2, 100);
        assertEq(suiAmount, 10);
    }

    function testIsTokenSupported() public {
        assertTrue(tokens.isTokenSupported(1));
        assertTrue(!tokens.isTokenSupported(0));
    }

    function testGetSuiDecimal() public {
        assertEq(tokens.getSuiDecimal(1), 8);
    }

    function testConvertEthToSuiDecimal() public {
        // ETH
        assertEq(IERC20Metadata(wETH).decimals(), 18);
        uint256 ethAmount = 10 ether;
        uint64 suiAmount = tokens.convertEthToSuiDecimal(BridgeMessage.ETH, ethAmount);
        assertEq(suiAmount, 10_000_000_00); // 10 * 10 ^ 8

        // USDC
        assertEq(IERC20Metadata(USDC).decimals(), 6);
        ethAmount = 50_000_000; // 50 USDC
        suiAmount = tokens.convertEthToSuiDecimal(BridgeMessage.USDC, ethAmount);
        assertEq(suiAmount, ethAmount);

        // USDT
        assertEq(IERC20Metadata(USDT).decimals(), 6);
        ethAmount = 60_000_000; // 60 USDT
        suiAmount = tokens.convertEthToSuiDecimal(BridgeMessage.USDT, ethAmount);
        assertEq(suiAmount, ethAmount);

        // BTC
        assertEq(IERC20Metadata(wBTC).decimals(), 8);
        ethAmount = 2_00_000_000; // 2 BTC
        suiAmount = tokens.convertEthToSuiDecimal(BridgeMessage.BTC, ethAmount);
        assertEq(suiAmount, ethAmount);
    }

    function testConvertSuiToEthDecimal() public {
        // ETH
        assertEq(IERC20Metadata(wETH).decimals(), 18);
        uint64 suiAmount = 11_000_000_00; // 11 eth
        uint256 ethAmount = tokens.convertSuiToEthDecimal(BridgeMessage.ETH, suiAmount);
        assertEq(ethAmount, 11 ether);

        // USDC
        assertEq(IERC20Metadata(USDC).decimals(), 6);
        suiAmount = 50_000_000; // 50 USDC
        ethAmount = tokens.convertSuiToEthDecimal(BridgeMessage.USDC, suiAmount);
        assertEq(suiAmount, ethAmount);

        // USDT
        assertEq(IERC20Metadata(USDT).decimals(), 6);
        suiAmount = 50_000_000; // 50 USDT
        ethAmount = tokens.convertSuiToEthDecimal(BridgeMessage.USDT, suiAmount);
        assertEq(suiAmount, ethAmount);

        // BTC
        assertEq(IERC20Metadata(wBTC).decimals(), 8);
        suiAmount = 3_000_000_00; // 3 BTC
        ethAmount = tokens.convertSuiToEthDecimal(BridgeMessage.BTC, suiAmount);
        assertEq(suiAmount, ethAmount);
    }
}
