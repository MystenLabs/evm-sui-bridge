// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/BridgeCommittee.sol";
import "../contracts/BridgeVault.sol";
import "../contracts/SuiBridge.sol";

contract BridgeBaseTest is Test {
    address committeeMemberA;
    address committeeMemberB;
    address committeeMemberC;
    address committeeMemberD;
    address deployer;

    // TODO: double check these addresses (they're from co-pilot)
    address wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    BridgeCommittee public committee;
    SuiBridge public bridge;
    BridgeVault public vault;

    function setUpBridgeTest() public {
        vm.createSelectFork(
            string.concat("https://mainnet.infura.io/v3/", vm.envString("INFURA_API_KEY"))
        );
        committeeMemberA = makeAddr("a");
        committeeMemberB = makeAddr("b");
        committeeMemberC = makeAddr("c");
        committeeMemberD = makeAddr("d");
        vm.deal(committeeMemberA, 1 ether);
        vm.deal(committeeMemberB, 1 ether);
        vm.deal(committeeMemberC, 1 ether);
        vm.deal(committeeMemberD, 1 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        address[] memory _committee = new address[](4);
        uint256[] memory _stake = new uint256[](4);
        _committee[0] = committeeMemberA;
        _committee[1] = committeeMemberB;
        _committee[2] = committeeMemberC;
        _committee[3] = committeeMemberD;
        _stake[0] = 1000;
        _stake[1] = 1000;
        _stake[2] = 1000;
        _stake[3] = 2000;
        committee = new BridgeCommittee();
        committee.initialize(_committee, _stake);
        vault = new BridgeVault();
        address[] memory _supportedTokens = new address[](4);
        _supportedTokens[0] = wBTC;
        _supportedTokens[1] = wETH;
        _supportedTokens[2] = USDC;
        _supportedTokens[3] = USDT;
        bridge = new SuiBridge();
        bridge.initialize(_supportedTokens, address(committee), address(vault), wETH);
    }

    function test() public {}
}
