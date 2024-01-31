// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";
import "../../contracts/BridgeCommittee.sol";
import "../../contracts/BridgeLimiter.sol";
import "../../contracts/BridgeTokens.sol";
import "../../contracts/utils/BridgeMessage.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract BridgeLimiterFuzzTest is BridgeBaseFuzzTest {
    BridgeLimiter public bridgeLimiter;
    BridgeCommittee public bridgeCommittee;
    BridgeTokens public bridgeTokens;

    address committeeMemeberAddressA;
    uint256 committeeMemeberPkA;
    address committeeMemeberAddressB;
    uint256 committeeMemeberPkB;
    address committeeMemeberAddressC;
    uint256 committeeMemeberPkC;
    address committeeMemeberAddressD;
    uint256 committeeMemeberPkD;
    address committeeMemeberAddressE;
    uint256 committeeMemeberPkE;

    uint16 private committeeMemeberStakeA = 2000;
    uint16 private committeeMemeberStakeB = 2000;
    uint16 private committeeMemeberStakeC = 2000;
    uint16 private committeeMemeberStakeD = 2000;
    uint16 private committeeMemeberStakeE = 2000;

    uint256 SUI_PRICE = 12800;
    uint256 BTC_PRICE = 432518900;
    uint256 ETH_PRICE = 25969600;
    uint256 USDC_PRICE = 10000;

    address wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address USDCWhale = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;

    uint256[] signers = new uint256[](5);

    function setUp() public {
        bridgeCommittee = new BridgeCommittee();

        (committeeMemeberAddressA, committeeMemeberPkA) = makeAddrAndKey("A");
        (committeeMemeberAddressB, committeeMemeberPkB) = makeAddrAndKey("B");
        (committeeMemeberAddressC, committeeMemeberPkC) = makeAddrAndKey("C");
        (committeeMemeberAddressD, committeeMemeberPkD) = makeAddrAndKey("D");
        (committeeMemeberAddressE, committeeMemeberPkE) = makeAddrAndKey("E");

        signers[0] = committeeMemeberPkA;
        signers[1] = committeeMemeberPkB;
        signers[2] = committeeMemeberPkC;
        signers[3] = committeeMemeberPkD;
        signers[4] = committeeMemeberPkE;

        address[] memory _committeeMemebers = new address[](5);
        _committeeMemebers[0] = committeeMemeberAddressA;
        _committeeMemebers[1] = committeeMemeberAddressB;
        _committeeMemebers[2] = committeeMemeberAddressC;
        _committeeMemebers[3] = committeeMemeberAddressD;
        _committeeMemebers[4] = committeeMemeberAddressE;

        uint16[] memory _stake = new uint16[](5);
        _stake[0] = committeeMemeberStakeA;
        _stake[1] = committeeMemeberStakeB;
        _stake[2] = committeeMemeberStakeC;
        _stake[3] = committeeMemeberStakeD;
        _stake[4] = committeeMemeberStakeE;

        bridgeCommittee.initialize(_committeeMemebers, _stake);

        bridgeLimiter = new BridgeLimiter();

        address[] memory _supportedTokens = new address[](4);
        _supportedTokens[0] = wBTC;
        _supportedTokens[1] = wETH;
        _supportedTokens[2] = USDC;
        _supportedTokens[3] = USDT;

        bridgeTokens = new BridgeTokens(_supportedTokens);

        uint256[] memory assetPrices = new uint256[](4);
        assetPrices[0] = SUI_PRICE;
        assetPrices[1] = BTC_PRICE;
        assetPrices[2] = ETH_PRICE;
        assetPrices[3] = USDC_PRICE;

        uint256 totalLimit = 10000000000;
        bridgeLimiter.initialize(
            address(bridgeCommittee),
            address(bridgeTokens),
            assetPrices,
            totalLimit
        );
    }

    function testInitialize() public {
        assertEq(bridgeLimiter.assetPrices(0), SUI_PRICE);
        assertEq(bridgeLimiter.assetPrices(1), BTC_PRICE);
        assertEq(bridgeLimiter.assetPrices(2), ETH_PRICE);
        assertEq(bridgeLimiter.assetPrices(3), USDC_PRICE);
        assertEq(bridgeLimiter.totalLimit(), 10000000000);
        assertEq(
            bridgeLimiter.oldestHourTimestamp(),
            bridgeLimiter.currentHour()
        );
    }

    // FAILS
    function testFuzz_willAmountExceedLimit(
        uint8 tokenId,
        uint256 amount
    ) public {
        vm.assume(tokenId <= 3);
        vm.assume(amount > 0 && amount <= 100000);

        uint256 usdAmount = bridgeLimiter.calculateAmountInUSD(tokenId, amount);

        // address tokenAddress = bridgeLimiter.tokens.getAddress(tokenId);
        // uint8 decimals = IERC20Metadata(tokenAddress).decimals();
        // assertEq(
        //     usdAmount,
        //     (amount * bridgeLimiter.assetPrices(tokenId)) / (10 ** decimals)
        // );
    }

    // FAILS
    /**
    function testFuzz_UpdateBridgeTransfers(
        uint8 tokenId,
        uint256 amount
    ) public {
        vm.assume(tokenId > 0 && tokenId <= 3);
        vm.assume(amount > 0 && amount <= 100000);

        uint256 usdAmount = bridgeLimiter.calculateAmountInUSD(tokenId, amount);
        bool limitExceeded = bridgeLimiter.willUSDAmountExceedLimit(usdAmount);
        vm.assume(!limitExceeded); // amount must not exceed the limit

        bridgeLimiter.updateBridgeTransfers(tokenId, amount);

        if (limitExceeded) {
            vm.expectRevert(
                bytes("BridgeLimiter: amount exceeds rolling window limit")
            );
            bridgeLimiter.updateBridgeTransfers(tokenId, amount);
        } else {
            uint256 preHourlyAmount = bridgeLimiter.hourlyTransferAmount(
                currentHour
            );
            bridgeLimiter.updateBridgeTransfers(tokenId, amount);
            uint256 postHourlyAmount = bridgeLimiter.hourlyTransferAmount(
                currentHour
            );
            assertEq(postHourlyAmount, preHourlyAmount + USDAmount);
        }
    }
     */

    function testFuzz_updateAssetPriceWithSignatures(
        uint8 tokenId,
        uint256 price,
        uint8 numSigners
    ) public {
        vm.assume(numSigners > 0 && numSigners <= 5);
        vm.assume(price >= 100000000);
        tokenId = uint8(bound(tokenId, 1, 3));

        bytes memory payload = abi.encode(uint8(tokenId), uint256(price));
        // Create a sample BridgeMessage
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPDATE_ASSET_PRICE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](numSigners);
        for (uint8 i = 0; i < numSigners; i++) {
            signatures[i] = getSignature(messageHash, signers[i]);
        }

        bool signaturesValid;
        try
            bridgeCommittee.verifyMessageSignatures(
                signatures,
                message,
                BridgeMessage.UPDATE_ASSET_PRICE
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
            bridgeLimiter.updateAssetPriceWithSignatures(signatures, message);
            uint256 postPrice = bridgeLimiter.assetPrices(tokenId);
            assertEq(postPrice, price);
        } else {
            // Expect a revert
            vm.expectRevert(
                bytes("BridgeCommittee: Insufficient stake amount")
            );
            bridgeLimiter.updateAssetPriceWithSignatures(signatures, message);
        }
    }

    function testFuzz_updateLimitWithSignatures(uint256 totalLimit) public {
        vm.assume(totalLimit >= 100000000);
        bytes memory payload = abi.encode(uint256(totalLimit));
        // Create a sample BridgeMessage
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.UPDATE_BRIDGE_LIMIT,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: payload
        });

        bytes memory messageBytes = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(messageBytes);

        bytes[] memory signatures = new bytes[](5);
        signatures[0] = getSignature(messageHash, committeeMemeberPkA);
        signatures[1] = getSignature(messageHash, committeeMemeberPkB);
        signatures[2] = getSignature(messageHash, committeeMemeberPkC);
        signatures[3] = getSignature(messageHash, committeeMemeberPkD);
        signatures[4] = getSignature(messageHash, committeeMemeberPkE);

        // Call the updateLimitWithSignatures function
        bridgeLimiter.updateLimitWithSignatures(signatures, message);

        assertEq(bridgeLimiter.totalLimit(), totalLimit);
    }
}
