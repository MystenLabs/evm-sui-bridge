// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/BridgeCommittee.sol";
import "../contracts/BridgeVault.sol";
import "../contracts/SuiBridge.sol";

contract AccessManagerTest is Test {
    address committeeMemberA;
    address committeeMemberB;
    address committeeMemberC;
    address deployer;

    BridgeCommittee public committee;
    SuiBridge public bridge;
    BridgeVault public vault;

    // This funciton is called before each unit test
    function setUp() public {
        // TODO: setup tests
        committeeMemberA = makeAddr("a");
        committeeMemberB = makeAddr("b");
        committeeMemberC = makeAddr("c");
        vm.deal(committeeMemberA, 100 ether);
        vm.deal(committeeMemberB, 100 ether);
        vm.deal(committeeMemberC, 100 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        // TODO: define this with mock tokens
        address[] memory _supportedTokens = new address[](1);
        bridge = new SuiBridge();
        bridge.initialize(_supportedTokens);
        vault = new BridgeVault(address(bridge));
        address[] memory _committee = new address[](3);
        _committee[0] = committeeMemberA;
        _committee[1] = committeeMemberB;
        _committee[2] = committeeMemberC;
        committee = new BridgeCommittee(_committee, address(bridge));
    }

    function testBridgeCommitteeInitialization() public {
        // TODO: test the bridge committee has been initialized correctly
    }
}
