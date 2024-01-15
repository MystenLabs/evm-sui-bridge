// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../contracts/interfaces/ISuiBridge.sol";

contract SuiBridgeTest is BridgeBaseTest, ISuiBridge {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testSuiBridgeInitialization() public {
        assertTrue(bridge.supportedTokens(1) == wBTC);
        assertTrue(bridge.supportedTokens(2) == wETH);
        assertTrue(bridge.supportedTokens(3) == USDC);
        assertTrue(bridge.supportedTokens(4) == USDT);
        assertEq(address(bridge.committee()), address(committee));
        assertEq(address(bridge.vault()), address(vault));
        assertEq(address(bridge.weth9()), wETH);
        assertEq(bridge.chainId(), testChainID);
    }

    function testTransferTokensWithSignaturesInvalidSignatures() public {
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
        vm.expectRevert(bytes("SuiBridge: Invalid signatures"));
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
        vm.expectRevert(bytes("SuiBridge: message does not match type"));
        bridge.transferTokensWithSignatures(signatures, message);
    }

    function testTransferWETHWithValidSignatures() public {
        // Fill vault with WETH
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        // IWETH9(wETH).withdraw(1 ether);
        IERC20(wETH).transfer(address(vault), 10 ether);
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
        // Create transfer message
        BridgeMessage.TokenTransferPayload memory payload = BridgeMessage.TokenTransferPayload({
            senderAddressLength: 0,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 0,
            targetAddress: bridgerA,
            tokenId: BridgeMessage.USDC,
            amount: 1_000_000
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

        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        assert(IERC20(USDC).balanceOf(bridgerA) == 0);
        bridge.transferTokensWithSignatures(signatures, message);
        assert(IERC20(USDC).balanceOf(bridgerA) == 1_000_000);
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
        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);
        vm.expectRevert(bytes("SuiBridge: Invalid nonce"));
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

        vm.expectRevert(bytes("SuiBridge: message does not match type"));
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
        vm.expectRevert(bytes("SuiBridge: Invalid signatures"));
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

        vm.expectRevert(bytes("SuiBridge: Invalid nonce"));
        bridge.executeEmergencyOpWithSignatures(signatures, message);
    }

    function testUpgradeBridgeWithSignaturesInvalidSignatures() public {
        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BRIDGE_UPGRADE,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(0)
        });

        bytes memory encodedMessage = BridgeMessage.encodeMessage(message);

        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](2);
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        vm.expectRevert(bytes("SuiBridge: Invalid signatures"));
        bridge.upgradeBridgeWithSignatures(signatures, message);
    }

    function testUpgradeBridgeWithSignaturesMessageDoesNotMatchType() public {
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


        vm.expectRevert(bytes("SuiBridge: message does not match type"));
        bridge.upgradeBridgeWithSignatures(signatures, message);
    }


    function testUpgradeBridgeWithSignaturesInvalidNonce() public {
        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BRIDGE_UPGRADE,
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
        bridge.upgradeBridgeWithSignatures(signatures, message);

        vm.expectRevert(bytes("SuiBridge: Invalid nonce"));
        bridge.upgradeBridgeWithSignatures(signatures, message);
    }
    function testUpgradeBridgeWithSignatures() public {
        // Create emergency op message
        BridgeMessage.Message memory message = BridgeMessage.Message({
            messageType: BridgeMessage.BRIDGE_UPGRADE,
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
        bridge.upgradeBridgeWithSignatures(signatures, message);
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
            testChainID,
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
            testChainID,
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
            testChainID,
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

    function testAdjustDecimalsForSuiTokenEthDecimalShouldBeLargerThanSuiDecimal() public {
        vm.expectRevert(bytes("Eth decimal should be larger than sui decimal"));
        bridge.adjustDecimalsForSuiToken(BridgeMessage.ETH, 10 ether, 1);
    }

    function testAdjustDecimalsForSuiTokenAmountTooLargeForUint64() public {
        vm.expectRevert(bytes("Amount too large for uint64"));
        bridge.adjustDecimalsForSuiToken(BridgeMessage.ETH, type(uint256).max, BridgeMessage.SUI_DECIMAL_ON_SUI);
        vm.expectRevert(bytes("Amount too large for uint64"));
        bridge.adjustDecimalsForSuiToken(BridgeMessage.SUI, type(uint256).max, BridgeMessage.SUI_DECIMAL_ON_SUI);
    }

    function testAdjustDecimalsForSuiTokenTokenIdDoesNotHaveSuiDecimalSet() public {
        vm.expectRevert(bytes("TokenId does not have Sui decimal set"));
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
    function testUpgradeBridge() public {}
}
