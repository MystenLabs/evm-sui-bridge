// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BridgeBaseTest.t.sol";
import "./MockERC20.sol";

contract BridgeVaultTest is BridgeBaseTest {
    MockERC20 token;

    function setUp() public {
        setUpBridgeTest();
        // Deploy a mock ERC20 token
        token = new MockERC20("MockERC20", "MockERC20");
    }

    function testTransferERC20() public {
        // Deploy the bridge vault with alice as the owner
        vault = new BridgeVault(address(wETH));

        // Mint some tokens for the bridge vault
        MockERC20(address(token)).mint(address(vault), 1000);

        // Transfer some tokens from the vault to bob
        vault.transferERC20(address(token), bridgerB, 500);

        // Check that the transfer was successful
        assertEq(token.balanceOf(bridgerB), 500);
        assertEq(token.balanceOf(address(vault)), 500);

        vault.transferERC20(address(token), bridgerC, 500);

        assertEq(token.balanceOf(bridgerC), 500);
    }

    // TODO: testTransferETH
}
