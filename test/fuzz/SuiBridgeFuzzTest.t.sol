// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";

contract SuiBridgeFuzzTest is BridgeBaseFuzzTest {
    function setUp() public {
        setUpBridgeFuzzTest();
    }

    function testFuzz_executeEmergencyOpWithSignatures(
        uint8 numSigners
    ) public {
        vm.assume(numSigners > 0 && numSigners <= N);
        // Get current paused state
        bool isPaused = suiBridge.paused();

        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: suiBridge.nonces(BridgeMessage.EMERGENCY_OP),
            chainID: 1,
            payload: abi.encode(isPaused ? 1 : 0)
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                message.messageType
            )
        {
            // The call was successful
            signaturesValid = true;
        } catch Error(string memory) {
            signaturesValid = false;
        } catch (bytes memory) {
            signaturesValid = false;
        }

        if (signaturesValid) {
            suiBridge.executeEmergencyOpWithSignatures(signatures, message);
            assertEq(suiBridge.paused(), !isPaused);
            assertEq(suiBridge.nonces(message.messageType), message.nonce + 1);
        } else {
            // Expect a revert
            vm.expectRevert(
                bytes("BridgeCommittee: Insufficient stake amount")
            );
            suiBridge.executeEmergencyOpWithSignatures(signatures, message);
        }
    }

    function testFuzz_transferTokensWithSignatures(
        uint8 numSigners
    ) public {
        vm.assume(numSigners > 0 && numSigners <= N);
        skip(2 days);

        // Fill vault with WETH
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).transfer(address(bridgeVault), 10 ether);
        address targetAddress = 0xb18f79Fe671db47393315fFDB377Da4Ea1B7AF96;

        bytes
            memory payload = hex"2080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af960200000000000186a0";
        // Create transfer message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes
            memory expectedEncodedMessage = hex"5355495f4252494447455f4d45535341474500010000000000000001012080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af960200000000000186a0";
        assertEq(encodedMessage, expectedEncodedMessage);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        uint256 aBalance = targetAddress.balance;
        bool signaturesValid;
        try
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                message.messageType
            )
        {
            // The call was successful
            signaturesValid = true;
        } catch Error(string memory) {
            signaturesValid = false;
        } catch (bytes memory) {
            signaturesValid = false;
        }
        if (signaturesValid) {
            suiBridge.transferTokensWithSignatures(signatures, message);
            assertEq(targetAddress.balance, aBalance + 0.001 ether);
        } else {
            // Expect a revert
            vm.expectRevert(
                bytes("BridgeCommittee: Insufficient stake amount")
            );
            suiBridge.transferTokensWithSignatures(signatures, message);
        }
    }
}

        // uint8 senderAddressLength,
        // bytes senderAddress,
        // uint8 targetChain,
        // uint8 targetAddressLength,
        // address targetAddress,
        // uint8 tokenId,
        // uint64 amount