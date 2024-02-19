// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";

contract SuiBridgeFuzzTest is BridgeBaseFuzzTest {
    function setUp() public {
        setUpBridgeFuzzTest();
    }

    function testFuzz_executeEmergencyOpWithSignatures(uint8 numSigners) public {
        vm.assume(numSigners > 0 && numSigners <= N);
        // Get current paused state
        bool isPaused = suiBridge.paused();

        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: suiBridge.nonces(BridgeMessage.EMERGENCY_OP),
            chainID: BridgeBaseFuzzTest.chainID,
            payload: isPaused ? bytes(hex"01") : bytes(hex"00")
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try bridgeCommittee.verifySignatures(signatures, message) {
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
            vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
            suiBridge.executeEmergencyOpWithSignatures(signatures, message);
        }
    }

    /**
     * function testFuzz_transferTokensWithSignatures(uint8 numSigners, address targetAddress)
     *     // uint8 tokenId,
     *     // uint64 amount
     *     public
     * {
     *     vm.assume(numSigners > 0 && numSigners <= N);
     *     vm.assume(targetAddress != address(0));
     *     // tokenId = uint8(bound(tokenId, BridgeMessage.ETH, BridgeMessage.USDC));
     *     // amount = uint64(bound(amount, 1_000_000, BridgeBaseFuzzTest.totalLimit));
     *     uint64 amount = 1_000_000;
     *     skip(2 days);
     * 
     *     // Create transfer payload
     *     uint8 senderAddressLength = 32;
     *     bytes memory senderAddress = abi.encode(0);
     *     uint8 targetAddressLength = 20;
     * 
     *     // Create transfer message
     *     BridgeMessage.TokenTransferPayload memory payload = BridgeMessage.TokenTransferPayload({
     *         senderAddressLength: senderAddressLength,
     *         senderAddress: senderAddress,
     *         targetChain: 1,
     *         targetAddressLength: targetAddressLength,
     *         targetAddress: targetAddress,
     *         tokenId: BridgeMessage.ETH,
     *         // This is Sui amount (eth decimal 8)
     *         amount: 100_000_000
     *     });
     * 
     *     // Fill the vault
     *     changePrank(USDCWhale);
     *     IERC20(USDC).transfer(address(bridgeVault), amount);
     *     changePrank(deployer);
     *     IWETH9(wETH).deposit{value: 10 ether}();
     *     IERC20(wETH).transfer(address(bridgeVault), 10 ether);
     * 
     *     // address tokenAddress = getTokenAddress(tokenId);
     * 
     *     {
     *         // Create transfer message
     *         BridgeMessage.Message memory message = BridgeMessage.Message({
     *             messageType: BridgeMessage.TOKEN_TRANSFER,
     *             version: 1,
     *             nonce: 1,
     *             chainID: chainID,
     *             payload: abi.encode(payload)
     *         });
     *         bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
     * 
     *         bytes32 messageHash = keccak256(encodedMessage);
     *         bytes[] memory signatures = new bytes[](numSigners);
     *         for (uint8 i = 0; i < numSigners; i++) {
     *             signatures[i] = getSignature(messageHash, signers[i]);
     *         }
     * 
     *         bool validSignatures;
     *         try bridgeCommittee.verifySignatures(signatures, message) {
     *             // The call was successful
     *             validSignatures = true;
     *         } catch Error(string memory) {
     *             validSignatures = false;
     *         } catch (bytes memory) {
     *             validSignatures = false;
     *         }
     * 
     *         if (validSignatures) {
     *             // assert(IERC20(getTokenAddress(tokenId)).balanceOf(targetAddress) == 0);
     *             // uint256 targetAddressBalance = IERC20(USDC).balanceOf(targetAddress);
     *             suiBridge.transferBridgedTokensWithSignatures(signatures, message);
     *             // assert(IERC20(getTokenAddress(tokenId)).balanceOf(targetAddress) > 0);
     *             // assert(IERC20(USDC).balanceOf(targetAddress) == (targetAddressBalance + (amount / 100)));
     *         } else {
     *             // Expect a revert
     *             vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
     *             suiBridge.transferBridgedTokensWithSignatures(signatures, message);
     *         }
     *     }
     * }
     */
    function getTokenAddress(uint8 tokenId) private view returns (address) {
        if (tokenId == 1) {
            return wBTC;
        } else if (tokenId == 2) {
            return wETH;
        } else if (tokenId == 3) {
            return USDC;
        } else if (tokenId == 4) {
            return USDT;
        }
        return address(0);
    }
}