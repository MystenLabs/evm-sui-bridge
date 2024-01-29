// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";
import "../../contracts/BridgeCommittee.sol";
import "../../contracts/BridgeLimiter.sol";
import "../../contracts/BridgeTokens.sol";
import "../../contracts/utils/BridgeMessage.sol";

contract BridgeLimiterFuzzTest is BridgeBaseFuzzTest {
    BridgeLimiter public bridgeLimiter;
    BridgeCommittee public bridgeCommittee;

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

    function setUp() public {
        bridgeCommittee = new BridgeCommittee();

        (committeeMemeberAddressA, committeeMemeberPkA) = makeAddrAndKey("A");
        (committeeMemeberAddressB, committeeMemeberPkB) = makeAddrAndKey("B");
        (committeeMemeberAddressC, committeeMemeberPkC) = makeAddrAndKey("C");
        (committeeMemeberAddressD, committeeMemeberPkD) = makeAddrAndKey("D");
        (committeeMemeberAddressE, committeeMemeberPkE) = makeAddrAndKey("E");

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

        uint256 totalLimit = 10000000000;

        address[] memory _supportedTokens = new address[](4);
        _supportedTokens[0] = wBTC;
        _supportedTokens[1] = wETH;
        _supportedTokens[2] = USDC;
        _supportedTokens[3] = USDT;

        BridgeTokens bridgeTokens = new BridgeTokens(_supportedTokens);

        uint256[] memory assetPrices = new uint256[](4);
        assetPrices[0] = SUI_PRICE;
        assetPrices[1] = BTC_PRICE;
        assetPrices[2] = ETH_PRICE;
        assetPrices[3] = USDC_PRICE;

        bridgeLimiter.initialize(
            address(bridgeCommittee),
            address(bridgeTokens),
            assetPrices,
            totalLimit
        );
    }

    function testFuzz_updateAssetPriceWithSignatures(
        uint8 tokenId,
        uint256 amount
    ) public {
        vm.assume(amount >= 100000000);
        tokenId = uint8(bound(tokenId, 1, 3));

        bytes memory payload = abi.encode(uint8(tokenId), uint256(amount));
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

        bytes[] memory signatures = new bytes[](5);
        signatures[0] = getSignature(messageHash, committeeMemeberPkA);
        signatures[1] = getSignature(messageHash, committeeMemeberPkB);
        signatures[2] = getSignature(messageHash, committeeMemeberPkC);
        signatures[3] = getSignature(messageHash, committeeMemeberPkD);
        signatures[4] = getSignature(messageHash, committeeMemeberPkE);

        // Call the updateAssetPriceWithSignatures function
        bridgeLimiter.updateAssetPriceWithSignatures(signatures, message);

        // Assert that the asset price has been updated correctly
        assertEq(bridgeLimiter.assetPrices(tokenId), amount);
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
