// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./mocks/MockTokens.sol";
import "./BridgeBaseTest.t.sol";

contract BridgeTokensTest is BridgeBaseTest {
    function setUp() public {
        setUpBridgeTest();
    }

    function testBridgeTokensInitialization() public {
        assertTrue(tokens.supportedTokens(1) == wBTC);
        assertTrue(tokens.supportedTokens(2) == wETH);
        assertTrue(tokens.supportedTokens(3) == USDC);
        assertTrue(tokens.supportedTokens(4) == USDT);
    }

    function testGetAddress() public {
        assertEq(tokens.getAddress(1), wBTC);
    }

    function testAddToken() public {
        // create mock token
        address mockToken = address(new MockUSDC());
        changePrank(address(bridge));
        tokens.addToken(6, mockToken);
        assertEq(tokens.getAddress(6), mockToken);
    }

    function testRemoveToken() public {
        changePrank(address(bridge));
        tokens.removeToken(1);
        assertEq(tokens.getAddress(1), address(0));
    }
}
