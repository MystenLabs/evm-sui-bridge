// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "forge-std/Test.sol";
import "../contracts/BridgeVault.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {}

    function mint(address to, uint256 amount) public virtual {
        _mint(to, amount);
    }

    function burn(address form, uint amount) public virtual {
        _burn(form, amount);
    }
}

contract BridgeVaultTest is Test, BridgeVault {
    MockERC20 token;
    BridgeVault public vault;

    function setUp() public {
        // Deploy a mock ERC20 token
        token = new MockERC20("MockERC20", "MockERC20");
    }

    function testTransferERC20() public {
        address alice;
        address bob;
        address carol;

        uint256 alicePk;
        uint256 bobPk;
        uint256 carolPk;

        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (carol, carolPk) = makeAddrAndKey("carol");

        // Deploy the bridge vault with alice as the owner
        vault = new BridgeVault();

        // Mint some tokens for the bridge vault
        MockERC20(address(token)).mint(address(vault), 1000);

        // Transfer some tokens from the vault to bob
        vault.transferERC20(address(token), bob, 500);

        // Check that the transfer was successful
        assertEq(token.balanceOf(bob), 500);
        assertEq(token.balanceOf(address(vault)), 500);

        vault.transferERC20(address(token), carol, 500);

        assertEq(token.balanceOf(carol), 500);
    }

    function testBurn() public {
        address alice;
        address bob;
        address carol;

        uint256 alicePk;
        uint256 bobPk;
        uint256 carolPk;

        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        (carol, carolPk) = makeAddrAndKey("carol");

        // Deploy the bridge vault with alice as the owner
        vault = new BridgeVault();

        // Mint some tokens for the bridge vault
        MockERC20(address(token)).mint(address(vault), 1000);

        // Transfer some tokens from the vault to bob
        vault.transferERC20(address(token), bob, 500);

        // Check that the transfer was successful
        assertEq(token.balanceOf(bob), 500);
        assertEq(token.balanceOf(address(vault)), 500);

        // Burn some tokens from bob
        token.burn(bob, 100);

        // Check that the burn was successful
        assertEq(token.balanceOf(bob), 400);
        assertEq(token.balanceOf(address(vault)), 500);
    }
}
