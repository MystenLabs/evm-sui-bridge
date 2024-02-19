// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract BridgeLimiterFuzzTest is BridgeBaseFuzzTest {
    function setUp() public {
        setUpBridgeFuzzTest();
    }

    function testInitialize() public {
        assertEq(bridgeLimiter.assetPrices(0), SUI_PRICE);
        assertEq(bridgeLimiter.assetPrices(1), BTC_PRICE);
        assertEq(bridgeLimiter.assetPrices(2), ETH_PRICE);
        assertEq(bridgeLimiter.assetPrices(3), USDC_PRICE);
        assertEq(bridgeLimiter.totalLimit(), 10000000000);
        assertEq(bridgeLimiter.oldestHourTimestamp(), bridgeLimiter.currentHour());
    }

    function testFuzz_willAmountExceedLimit(uint8 tokenId, uint256 amount) public {
        tokenId = uint8(bound(tokenId, BridgeMessage.BTC, BridgeMessage.USDT));
        amount = uint8(bound(amount, 100_000_000, 100_000_000_000_000_000));

        bool expected = bridgeLimiter.calculateWindowAmount()
            + bridgeLimiter.calculateAmountInUSD(tokenId, amount) > bridgeLimiter.totalLimit();

        bool actual = bridgeLimiter.willAmountExceedLimit(tokenId, amount);

        assertEq(expected, actual);
    }

    function testFuzz_updateBridgeTransfers(uint8 tokenId, uint256 amount) public {
        tokenId = uint8(bound(tokenId, BridgeMessage.BTC, BridgeMessage.USDT));
        amount = uint8(bound(amount, 100_000_000, 100_000_000_000_000_000));

        bool expected = bridgeLimiter.willUSDAmountExceedLimit(
            bridgeLimiter.calculateAmountInUSD(tokenId, amount)
        );

        bool actual;
        try bridgeLimiter.updateBridgeTransfers(tokenId, amount) {
            // The call was successful
            actual = true;
        } catch Error(string memory) {
            actual = false;
        } catch (bytes memory) {
            actual = false;
        }

        assertEq(expected, actual);
    }

    function testFuzz_updateAssetPriceWithSignatures(uint8 numSigners, uint8 tokenId, uint64 price)
        public
    {
        vm.assume(numSigners > 0 && numSigners <= N);
        vm.assume(price >= 100000000);
        tokenId = uint8(bound(tokenId, BridgeMessage.BTC, BridgeMessage.USDT));

        bytes memory payload = abi.encodePacked(uint8(tokenId), uint64(price));
        // Create a sample BridgeMessage
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPDATE_ASSET_PRICE,
            version: 1,
            nonce: 0,
            chainID: BridgeBaseFuzzTest.chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

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
            bridgeLimiter.updateAssetPriceWithSignatures(signatures, message);
            uint256 postPrice = bridgeLimiter.assetPrices(tokenId);
            assertEq(postPrice, price);
        } else {
            // Expect a revert
            vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
            bridgeLimiter.updateAssetPriceWithSignatures(signatures, message);
        }
    }

    function testFuzz_updateLimitWithSignatures(
        uint8 numSigners,
        uint64 newLimit,
        uint8 sourceChainID
    ) public {
        vm.assume(numSigners > 0 && numSigners <= N);
        vm.assume(newLimit >= 100000000);
        vm.assume(sourceChainID >= 1 && sourceChainID <= 4);

        bytes memory payload = abi.encodePacked(sourceChainID, newLimit);
        // Create a sample BridgeMessage
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPDATE_BRIDGE_LIMIT,
            version: 1,
            nonce: 0,
            chainID: BridgeBaseFuzzTest.chainID,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

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
            // Call the updateLimitWithSignatures function
            bridgeLimiter.updateLimitWithSignatures(signatures, message);
            assertEq(bridgeLimiter.totalLimit(), newLimit);
        } else {
            // Expect a revert
            vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
            bridgeLimiter.updateLimitWithSignatures(signatures, message);
        }
    }
}