// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseFuzzTest.t.sol";
import "../../contracts/SuiBridge.sol";
import "../../contracts/BridgeCommittee.sol";
import "../../contracts/BridgeLimiter.sol";
import "../../contracts/BridgeTokens.sol";
import "../../contracts/BridgeVault.sol";

contract SuiBridgeFuzzTest is BridgeBaseFuzzTest {
    SuiBridge public suiBridge;
    BridgeVault public bridgeVault;
    BridgeTokens public bridgeTokens;
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

    address wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address USDCWhale = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;

    uint256 SUI_PRICE = 12800;
    uint256 BTC_PRICE = 432518900;
    uint256 ETH_PRICE = 25969600;
    uint256 USDC_PRICE = 10000;

    uint16 private committeeMemeberStakeA = 2000;
    uint16 private committeeMemeberStakeB = 2000;
    uint16 private committeeMemeberStakeC = 2000;
    uint16 private committeeMemeberStakeD = 2000;
    uint16 private committeeMemeberStakeE = 2000;

    uint8 public chainID = 99;
    uint256[] signers = new uint256[](5);

    // This function is called before each unit test
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

        uint256 totalLimit = 10000000000;

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

        bridgeLimiter.initialize(
            address(bridgeCommittee),
            address(bridgeTokens),
            assetPrices,
            totalLimit
        );

        suiBridge = new SuiBridge();
        suiBridge.initialize(
            address(bridgeCommittee),
            address(bridgeTokens),
            address(bridgeVault),
            address(bridgeLimiter),
            wETH,
            chainID
        );
    }

    function testFuzz_executeEmergencyOpWithSignatures(
        uint8 numSigners
    ) public {
        vm.assume(numSigners > 0 && numSigners <= 5);
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
}
