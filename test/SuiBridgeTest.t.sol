// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
        bytes memory payload = abi.encodePacked(
            senderAddressLength,
            senderAddress,
            targetChain,
            targetAddressLength,
            targetAddress,
            tokenId
        );
        // little endian encoded of u64 1_000_000
        bytes memory amountBytes = hex"00e1f50500000000";
        payload = bytes.concat(payload, amountBytes);

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

        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        uint256 aBalance = bridgerA.balance;
        bridge.transferTokensWithSignatures(signatures, message);
        assertEq(bridgerA.balance, aBalance + 1 ether);
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
        bytes memory payload = abi.encodePacked(
            senderAddressLength,
            senderAddress,
            targetChain,
            targetAddressLength,
            targetAddress,
            tokenId
        );
        // little endian encoded of u64 1_000_000
        bytes memory amountBytes = hex"40420f0000000000";
        payload = bytes.concat(payload, amountBytes);

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

        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        assert(IERC20(USDC).balanceOf(bridgerA) == 0);
        bridge.transferTokensWithSignatures(signatures, message);
        assert(IERC20(USDC).balanceOf(bridgerA) == 1_000_000);
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

        // Create signatures from alice, bob, and charlie
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

        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        bridge.executeEmergencyOpWithSignatures(signatures, message);
        assertFalse(bridge.paused());
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
            hex"2080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af960290d0030000000000";
        // Create transfer message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.TOKEN_TRANSFER,
            version: 1,
            nonce: 4,
            chainID: 1,
            payload: payload
        });
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes memory expectedEncodedMessage =
            hex"5355495f4252494447455f4d45535341474500010400000000000000012080ab1ee086210a3a37355300ca24672e81062fcdb5ced6618dab203f6a3b291c0b14b18f79fe671db47393315ffdb377da4ea1b7af960290d0030000000000";

        assertEq(encodedMessage, expectedEncodedMessage);

        bytes[] memory signatures = new bytes[](2);

        signatures[0] =
            hex"0518a39b869f3765c88e27a5889867c16fa994c6ba7d2bd9672268656a08ac536c0eaddfc2285035e720dafdaca631c1aad9e3c622f0a6d500d7392cc60a0fc401";
        signatures[1] =
            hex"93029995ee7034f0b518fbdab29302f7f4d45682e96a16802226674fecb7f1e60179df724eec6c60e05ede02375028966dd09aaadc564487ce24b6c797b8a24900";

        uint256 aBalance = targetAddress.balance;
        committee.verifyMessageSignatures(signatures, message, BridgeMessage.TOKEN_TRANSFER);

        bridge.transferTokensWithSignatures(signatures, message);
        assertEq(targetAddress.balance, aBalance + 0.0025 ether);
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
        MockSuiBridgeV2 newBridge = new MockSuiBridgeV2();
        // generate upgrade message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BRIDGE_UPGRADE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(address(newBridge), 0)
        });

        // create signatures
        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);
        bytes32 messageHash = keccak256(encodedMessage);
        bytes[] memory signatures = new bytes[](4);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        // execute upgrade
        // bridge.executeUpgradeWithSignatures(signatures, message);

        assertTrue(bridge.paused());
        newBridge.newMockFunction();
        assertFalse(bridge.paused());
    }
}
