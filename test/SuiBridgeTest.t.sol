// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";

contract SuiBridgeTest is BridgeBaseTest {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testSuiBridgeInitialization() public {
        assertTrue(bridge.supportedTokens(0) == wBTC);
        assertTrue(bridge.supportedTokens(1) == wETH);
        assertTrue(bridge.supportedTokens(2) == USDC);
        assertTrue(bridge.supportedTokens(3) == USDT);
        assertEq(address(bridge.committee()), address(committee));
        assertEq(address(bridge.vault()), address(vault));
        assertEq(address(bridge.weth9()), wETH);
        assertEq(bridge.chainId(), 1);
    }

    function testTransferWETHWithValidSignatures() public {
        // Fill vault with WETH
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).transfer(address(vault), 10 ether);
        // Create transfer message
        Messages.TokenTransferPayload memory payload = Messages.TokenTransferPayload({
            senderAddressLength: 0,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 0,
            targetAddress: bridgerA,
            tokenType: 1,
            amount: 1 ether
        });

        Messages.Message memory message = Messages.Message({
            messageType: Messages.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(payload)
        });

        bytes memory encodedMessage = encodeMessage(message);

        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);

        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        assert(IERC20(wETH).balanceOf(bridgerA) == 0);
        bridge.transferTokensWithSignatures(signatures, message);
        assert(IERC20(wETH).balanceOf(bridgerA) == 1 ether);
    }

    function testTransferUSDCWithValidSignatures() public {}

    function testFreezeBridgeEmergencyOp() public {}

    function testUnfreezeBridgeEmergencyOp() public {}

    function testBridgeToSui() public {}

    function testBridgeEthToSui() public {}

    function testUpgradeBridge() public {}
}
