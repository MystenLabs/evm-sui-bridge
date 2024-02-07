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
            chainID: BridgeBaseFuzzTest.chainID,
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
            bridgeCommittee.verifySignatures(
                signatures,
                message
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
        uint8 numSigners,
        address targetAddress,
        // uint8 tokenId,
        uint64 amount
    ) public {
        vm.assume(numSigners > 3 && numSigners <= N);
        vm.assume(targetAddress != address(0));
        // tokenId = uint8(bound(tokenId, BridgeMessage.BTC, BridgeMessage.USDT));
        amount = uint64(bound(amount, 1_000_000, BridgeBaseFuzzTest.totalLimit));
        skip(2 days);

        // Create transfer payload
        uint8 senderAddressLength = 32;
        bytes memory senderAddress = abi.encode(0);
        uint8 targetChain = BridgeBaseFuzzTest.chainID;
        uint8 targetAddressLength = 20;
        uint8 tokenId = BridgeMessage.USDC;
        bytes memory payload = abi.encodePacked(
            senderAddressLength,
            senderAddress,
            targetChain,
            targetAddressLength,
            targetAddress,
            tokenId,
            amount
        );

       // Fill the vault
        changePrank(USDCWhale);
        IERC20(USDC).transfer(address(bridgeVault), amount);
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).transfer(address(bridgeVault), 10 ether);

        {
        // Create transfer message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: chainID,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }
        
        bool signaturesValid;
        try
            bridgeCommittee.verifySignatures(
                signatures,
                message
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
            assert(IERC20(USDC).balanceOf(targetAddress) == 0);
            // uint256 targetAddressBalance = IERC20(USDC).balanceOf(targetAddress);
            suiBridge.transferTokensWithSignatures(signatures, message);
            assert(IERC20(USDC).balanceOf(targetAddress) > 0);
            // assert(IERC20(USDC).balanceOf(targetAddress) == (targetAddressBalance + (amount / 100)));
        } else {
            // Expect a revert
            vm.expectRevert(
                bytes("BridgeCommittee: Insufficient stake amount")
            );
            suiBridge.transferTokensWithSignatures(signatures, message);
        }
        }
    }
}
