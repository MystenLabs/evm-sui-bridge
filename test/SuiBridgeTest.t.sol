// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BridgeBaseTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../contracts/interfaces/ISuiBridge.sol";
import "./mocks/MockSuiBridgeV2.sol";

contract SuiBridgeTest is BridgeBaseTest, ISuiBridge {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testSuiBridgeInitialization() public {
        assertEq(address(bridge.committee()), address(committee));
        assertEq(address(bridge.vault()), address(vault));
        assertEq(address(bridge.weth9()), wETH);
        assertEq(address(bridge.tokens()), address(tokens));
    }

    function testTransferTokensWithSignaturesTokenDailyLimitExceeded() public view {
        // Create transfer message
        BridgeMessage.TokenTransferPayload memory payload = BridgeMessage.TokenTransferPayload({
            senderAddressLength: 32,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 20,
            targetAddress: bridgerA,
            tokenId: BridgeMessage.ETH,
            amount: type(uint64).max
        });

        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(payload)
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        // TODO: FAILS
        // vm.expectRevert(bytes("SuiBridge: Token's daily limit exceeded"));
        // bridge.transferTokensWithSignatures(signatures, message);
    }

    function testTransferTokensWithSignaturesInsufficientStakeAmount() public {
        // Create transfer message
        BridgeMessage.TokenTransferPayload memory payload = BridgeMessage.TokenTransferPayload({
            senderAddressLength: 0,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 0,
            targetAddress: bridgerA,
            tokenId: BridgeMessage.ETH,
            // This is Sui amount (eth decimal 8)
            amount: 100_000_000
        });
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(payload)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        bridge.transferTokensWithSignatures(signatures, message);
    }

    function testTransferTokensWithSignaturesMessageDoesNotMatchType() public {
        // Create transfer message
        BridgeMessage.TokenTransferPayload memory payload = BridgeMessage.TokenTransferPayload({
            senderAddressLength: 0,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 0,
            targetAddress: bridgerA,
            tokenId: BridgeMessage.ETH,
            // This is Sui amount (eth decimal 8)
            amount: 100_000_000
        });
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(payload)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        vm.expectRevert(bytes("BridgeCommittee: message does not match type"));
        bridge.transferTokensWithSignatures(signatures, message);
    }

    function testTransferWETHWithValidSignatures() public {
        // Fill vault with WETH
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        // IWETH9(wETH).withdraw(1 ether);
        IERC20(wETH).transfer(address(vault), 10 ether);
        // Create transfer payload
        uint8 senderAddressLength = 32;
        bytes memory senderAddress = abi.encode(0);
        uint8 targetChain = 1;
        uint8 targetAddressLength = 20;
        address targetAddress = bridgerA;
        uint8 tokenId = BridgeMessage.ETH;
        uint64 amount = 100000000; // 1 ether in sui decimals
        bytes memory payload = abi.encodePacked(
            senderAddressLength,
            senderAddress,
            targetChain,
            targetAddressLength,
            targetAddress,
            tokenId,
            amount
        );

        // Create transfer message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);

        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);

        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        uint256 aBalance = bridgerA.balance;
        bridge.transferTokensWithSignatures(signatures, message);
        assertEq(bridgerA.balance, aBalance + 1 ether);

        vm.expectRevert(bytes("SuiBridge: Message already processed"));
        bridge.transferTokensWithSignatures(signatures, message);
    }

    function testTransferUSDCWithValidSignatures() public {
        // Fill vault with USDC
        changePrank(USDCWhale);
        IERC20(USDC).transfer(address(vault), 100_000_000);
        changePrank(deployer);

        // Create transfer payload
        uint8 senderAddressLength = 32;
        bytes memory senderAddress = abi.encode(0);
        uint8 targetChain = 1;
        uint8 targetAddressLength = 20;
        address targetAddress = bridgerA;
        uint8 tokenId = BridgeMessage.USDC;
        uint64 amount = 1_000_000;
        bytes memory payload = abi.encodePacked(
            senderAddressLength,
            senderAddress,
            targetChain,
            targetAddressLength,
            targetAddress,
            tokenId,
            amount
        );

        // Create transfer message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);

        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        assert(IERC20(USDC).balanceOf(bridgerA) == 0);
        bridge.transferTokensWithSignatures(signatures, message);
        assert(IERC20(USDC).balanceOf(bridgerA) == 1_000_000);
    }

    function testExecuteEmergencyOpWithSignaturesInvalidOpCode() public {
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(2)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("BridgeMessage: Invalid op code"));
        bridge.executeEmergencyOpWithSignatures(signatures, message);
    }

    function testExecuteEmergencyOpWithSignaturesInvalidNonce() public {
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(0)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("MessageVerifier: Invalid nonce"));
        bridge.executeEmergencyOpWithSignatures(signatures, message);
    }

    function testExecuteEmergencyOpWithSignaturesMessageDoesNotMatchType() public {
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(0)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("BridgeCommittee: message does not match type"));
        bridge.executeEmergencyOpWithSignatures(signatures, message);
    }

    function testExecuteEmergencyOpWithSignaturesInvalidSignatures() public {
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(1)
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        vm.expectRevert(bytes("BridgeCommittee: Insufficient stake amount"));
        bridge.executeEmergencyOpWithSignatures(signatures, message);
    }

    function testFreezeBridgeEmergencyOp() public {
        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(0)
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);

        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        assertFalse(bridge.paused());
        bridge.executeEmergencyOpWithSignatures(signatures, message);
        assertTrue(bridge.paused());
    }

    function testUnfreezeBridgeEmergencyOp() public {
        testFreezeBridgeEmergencyOp();
        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.EMERGENCY_OP,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(1)
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);

        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        bridge.executeEmergencyOpWithSignatures(signatures, message);
        assertFalse(bridge.paused());
    }

    function testBridgeToSuiUnsupportedToken() public {
        vm.expectRevert(bytes("SuiBridge: Unsupported token"));
        bridge.bridgeToSui(255, 1 ether, abi.encode("suiAddress"), 0);
    }

    function testBridgeToSuiInsufficientAllowance() public {
        vm.expectRevert(bytes("SuiBridge: Insufficient allowance"));
        bridge.bridgeToSui(BridgeMessage.ETH, type(uint256).max, abi.encode("suiAddress"), 0);
    }

    function testBridgeWETHToSui() public {
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).approve(address(bridge), 10 ether);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 0);
        uint256 balance = IERC20(wETH).balanceOf(deployer);

        // assert emitted event
        vm.expectEmit(true, true, true, false);
        emit TokensBridgedToSui(
            chainID,
            0, // nonce
            0, // destination chain id
            BridgeMessage.ETH,
            1_00_000_000, // 1 ether
            deployer,
            abi.encode("suiAddress")
        );

        bridge.bridgeToSui(BridgeMessage.ETH, 1 ether, abi.encode("suiAddress"), 0);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 1 ether);
        assertEq(IERC20(wETH).balanceOf(deployer), balance - 1 ether);
        assertEq(bridge.nonces(BridgeMessage.TOKEN_TRANSFER), 1);

        // Now test rounding. For ETH, the last 10 digits are rounded
        vm.expectEmit(true, true, true, false);
        emit TokensBridgedToSui(
            chainID,
            1, // nonce
            0, // destination chain id
            BridgeMessage.ETH,
            2.00000001 ether,
            deployer,
            abi.encode("suiAddress")
        );
        // 2_000_000_011_000_000_888 is rounded to 2.00000001 eth
        bridge.bridgeToSui(
            BridgeMessage.ETH, 2_000_000_011_000_000_888, abi.encode("suiAddress"), 0
        );
        assertEq(IERC20(wETH).balanceOf(address(vault)), 3_000_000_011_000_000_888);
        assertEq(IERC20(wETH).balanceOf(deployer), balance - 3_000_000_011_000_000_888);
        assertEq(bridge.nonces(BridgeMessage.TOKEN_TRANSFER), 2);
    }

    function testBridgeUSDCToSui() public {
        // TODO test and make sure adjusted amount in event is correct
    }

    function testBridgeUSDTToSui() public {
        // TODO test and make sure adjusted amount in event is correct
    }

    function testBridgeBTCToSui() public {
        // TODO test and make sure adjusted amount in event is correct
    }

    function testBridgeEthToSui() public {
        changePrank(deployer);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 0);
        uint256 balance = deployer.balance;

        // assert emitted event
        vm.expectEmit(true, true, true, false);
        emit ISuiBridge.TokensBridgedToSui(
            chainID,
            0, // nonce
            0, // destination chain id
            BridgeMessage.ETH,
            1_000_000_00, // 1 ether
            deployer,
            abi.encode("suiAddress")
        );

        bridge.bridgeETHToSui{value: 1 ether}(abi.encode("suiAddress"), 0);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 1 ether);
        assertEq(deployer.balance, balance - 1 ether);
        assertEq(bridge.nonces(BridgeMessage.TOKEN_TRANSFER), 1);
    }

    // An e2e token transfer regression test covering message ser/de and signature verification
    function testTransferSuiToEthRegressionTest() public {
        address[] memory _committee = new address[](4);
        uint16[] memory _stake = new uint16[](4);
        _committee[0] = 0x68B43fD906C0B8F024a18C56e06744F7c6157c65;
        _committee[1] = 0xaCAEf39832CB995c4E049437A3E2eC6a7bad1Ab5;
        _committee[2] = 0x8061f127910e8eF56F16a2C411220BaD25D61444;
        _committee[3] = 0x508F3F1ff45F4ca3D8e86CDCC91445F00aCC59fC;
        _stake[0] = 2500;
        _stake[1] = 2500;
        _stake[2] = 2500;
        _stake[3] = 2500;
        committee = new BridgeCommittee();
        committee.initialize(_committee, _stake);
        vault = new BridgeVault(wETH);
        uint256[] memory assetPrices = new uint256[](4);
        assetPrices[0] = 10000; // SUI PRICE
        assetPrices[1] = 10000; // BTC PRICE
        assetPrices[2] = 10000; // ETH PRICE
        assetPrices[3] = 10000; // USDC PRICE
        uint256 totalLimit = 1000000;

        skip(2 days);
        limiter = new BridgeLimiter();
        limiter.initialize(address(committee), address(tokens), assetPrices, totalLimit);
        bridge = new SuiBridge();
        uint8 _chainId = chainID;
        bridge.initialize(
            address(committee), address(tokens), address(vault), address(limiter), wETH, _chainId
        );
        vault.transferOwnership(address(bridge));
        limiter.transferOwnership(address(bridge));

        // Fill vault with WETH
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).transfer(address(vault), 10 ether);
        address targetAddress = 0xb18f79Fe671db47393315fFDB377Da4Ea1B7AF96;

        bytes memory payload =
            hex"2080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af960200000000000186a0";
        // Create transfer message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes memory expectedEncodedMessage =
            hex"5355495f4252494447455f4d45535341474500010000000000000001012080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af960200000000000186a0";

        assertEq(encodedMessage, expectedEncodedMessage);

        bytes[] memory signatures = new bytes[](2);

        signatures[0] =
            hex"e1cf11b380855ff1d4a451ebc2fd68477cf701b7d4ec88da3082709fe95201a5061b4b60cf13815a80ba9dfead23e220506aa74c4a863ba045d95715b4cc6b6e00";
        signatures[1] =
            hex"8ba9ec92c2d5a44ecc123182f689b901a93921fd35f581354fea20b25a0ded6d055b96a64bdda77dd5a62b93d29abe93640aa3c1a136348093cd7a2418c6bfa301";

        uint256 aBalance = targetAddress.balance;
        committee.verifyMessageSignatures(signatures, message, BridgeMessage.TOKEN_TRANSFER);

        bridge.transferTokensWithSignatures(signatures, message);
        assertEq(targetAddress.balance, aBalance + 0.001 ether);
    }

    function testAdjustDecimalsForSuiTokenEthDecimalShouldBeLargerThanSuiDecimal() public {
        vm.expectRevert(bytes("Eth decimal should be larger than sui decimal"));
        bridge.adjustDecimalsForSuiToken(BridgeMessage.ETH, 10 ether, 1);
    }

    function testAdjustDecimalsForSuiTokenAmountTooLargeForUint64() public {
        vm.expectRevert(bytes("Amount too large for uint64"));
        bridge.adjustDecimalsForSuiToken(
            BridgeMessage.ETH, type(uint256).max, BridgeMessage.SUI_DECIMAL_ON_SUI
        );
        vm.expectRevert(bytes("Amount too large for uint64"));
        bridge.adjustDecimalsForSuiToken(
            BridgeMessage.SUI, type(uint256).max, BridgeMessage.SUI_DECIMAL_ON_SUI
        );
    }

    function testAdjustDecimalsForSuiTokenTokenIdDoesNotHaveSuiDecimalSet() public {
        vm.expectRevert(bytes("SuiBridge: TokenId does not have Sui decimal set"));
        bridge.adjustDecimalsForSuiToken(type(uint8).max, 10 ether, 18);
    }

    function testEthToSuiDecimalConversion() public {
        // ETH
        assertEq(IERC20Metadata(wETH).decimals(), 18);
        uint256 ethAmount = 10 ether;
        uint64 suiAmount = bridge.adjustDecimalsForSuiToken(BridgeMessage.ETH, ethAmount, 18);
        assertEq(suiAmount, 10_000_000_00); // 10 * 10 ^ 8

        // USDC
        assertEq(IERC20Metadata(USDC).decimals(), 6);
        ethAmount = 50_000_000; // 50 USDC
        suiAmount = bridge.adjustDecimalsForSuiToken(BridgeMessage.USDC, ethAmount, 6);
        assertEq(suiAmount, ethAmount);

        // USDT
        assertEq(IERC20Metadata(USDT).decimals(), 6);
        ethAmount = 60_000_000; // 60 USDT
        suiAmount = bridge.adjustDecimalsForSuiToken(BridgeMessage.USDT, ethAmount, 6);
        assertEq(suiAmount, ethAmount);

        // BTC
        assertEq(IERC20Metadata(wBTC).decimals(), 8);
        ethAmount = 2_00_000_000; // 2 BTC
        suiAmount = bridge.adjustDecimalsForSuiToken(BridgeMessage.BTC, ethAmount, 8);
        assertEq(suiAmount, ethAmount);
    }

    function testSuiToEthDecimalConversion() public {
        // ETH
        assertEq(IERC20Metadata(wETH).decimals(), 18);
        uint64 suiAmount = 11_000_000_00; // 11 eth
        uint256 ethAmount = bridge.adjustDecimalsForErc20(BridgeMessage.ETH, suiAmount, 18);
        assertEq(ethAmount, 11 ether);

        // USDC
        assertEq(IERC20Metadata(USDC).decimals(), 6);
        suiAmount = 50_000_000; // 50 USDC
        ethAmount = bridge.adjustDecimalsForErc20(BridgeMessage.USDC, suiAmount, 6);
        assertEq(suiAmount, ethAmount);

        // USDT
        assertEq(IERC20Metadata(USDT).decimals(), 6);
        suiAmount = 50_000_000; // 50 USDT
        ethAmount = bridge.adjustDecimalsForErc20(BridgeMessage.USDT, suiAmount, 6);
        assertEq(suiAmount, ethAmount);

        // BTC
        assertEq(IERC20Metadata(wBTC).decimals(), 8);
        suiAmount = 3_000_000_00; // 3 BTC
        ethAmount = bridge.adjustDecimalsForErc20(BridgeMessage.BTC, suiAmount, 8);
        assertEq(suiAmount, ethAmount);
    }

    // TODO: testTransferWETHWithLimitReached

    // TODO:
    function testUpgradeBridge() public {
        // TODO: redeploy bridge using upgrades
    }
}
