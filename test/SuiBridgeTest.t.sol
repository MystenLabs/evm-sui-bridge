// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";

contract SuiBridgeTest is BridgeBaseTest {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testSuiBridgeInitialization() public {
        // TODO: test bridge initialization
    }

    // TESTS:
    // - testTransferTokensWithValidSignatures
    // - testTransferTokensWithInvalidSignatures
    // - testFreezeBridgeEmergencyOp
    // - testUnfreezeBridgeEmergencyOp
    // - testBridgeToSui
    // - testBridgeEthToSui
    // - testUpgradeBridge
}
