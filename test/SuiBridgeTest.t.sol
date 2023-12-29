// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BridgeBaseTest.t.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SuiBridgeTest is BridgeBaseTest {
    // This function is called before each unit test
    function setUp() public {
        setUpBridgeTest();
    }

    function testSuiBridgeInitialization() public {
        assertTrue(bridge.supportedTokens(0) == wBTC);
        assertTrue(bridge.supportedTokens(1) == wETH);
        assertTrue(bridge.supportedTokens(2) == USDC);
        assertTrue(bridge.supportedTokens(3) == USDT);
        assertEq(address(bridge.committee()), address(committee));
        assertEq(address(bridge.vault()), address(vault));
        assertEq(address(bridge.weth9()), wETH);
        assertEq(bridge.chainId(), TestChainID);
    }

    function testTransferWETHWithValidSignatures() public {
        // Fill vault with WETH
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).transfer(address(vault), 10 ether);
        // Create transfer message
        Messages.TokenTransferPayload memory payload = Messages.TokenTransferPayload({
            senderAddressLength: 0,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 0,
            targetAddress: bridgerA,
            tokenType: Messages.ETH,
            // This is Sui amount (eth decimal 8)
            amount: 100_000_000
        });

        Messages.Message memory message = Messages.Message({
            messageType: Messages.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(payload)
        });

        bytes memory encodedMessage = encodeMessage(message);

        bytes32 messageHash = keccak256(encodedMessage);

        bytes[] memory signatures = new bytes[](4);

        // Create signatures from alice, bob, and charlie
        signatures[0] = getSignature(messageHash, committeeMemberPkA);
        signatures[1] = getSignature(messageHash, committeeMemberPkB);
        signatures[2] = getSignature(messageHash, committeeMemberPkC);
        signatures[3] = getSignature(messageHash, committeeMemberPkD);

        assert(IERC20(wETH).balanceOf(bridgerA) == 0);
        bridge.transferTokensWithSignatures(signatures, message);
        assert(IERC20(wETH).balanceOf(bridgerA) == 1 ether);
    }

    function testTransferUSDCWithValidSignatures() public {
        // Fill vault with USDC
        changePrank(USDCWhale);
        IERC20(USDC).transfer(address(vault), 100_000_000);
        changePrank(deployer);
        // Create transfer message
        Messages.TokenTransferPayload memory payload = Messages.TokenTransferPayload({
            senderAddressLength: 0,
            senderAddress: abi.encode(0),
            targetChain: 1,
            targetAddressLength: 0,
            targetAddress: bridgerA,
            tokenType: Messages.USDC,
            amount: 1_000_000
        });

        Messages.Message memory message = Messages.Message({
            messageType: Messages.TOKEN_TRANSFER,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(payload)
        });

        bytes memory encodedMessage = encodeMessage(message);

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
        Messages.Message memory message = Messages.Message({
            messageType: Messages.EMERGENCY_OP,
            version: 1,
            nonce: 0,
            chainID: 1,
            payload: abi.encode(0)
        });

        bytes memory encodedMessage = encodeMessage(message);

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
        Messages.Message memory message = Messages.Message({
            messageType: Messages.EMERGENCY_OP,
            version: 1,
            nonce: 1,
            chainID: 1,
            payload: abi.encode(1)
        });

        bytes memory encodedMessage = encodeMessage(message);

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

    function testBridgeToSui() public {
        changePrank(deployer);
        IWETH9(wETH).deposit{value: 10 ether}();
        IERC20(wETH).approve(address(bridge), 10 ether);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 0);
        uint256 balance = IERC20(wETH).balanceOf(deployer);

        // assert emitted event
        vm.expectEmit(true, true, true, false);
        emit ISuiBridge.TokensBridgedToSui(
            TestChainID,
            0, // nonce
            0, // destination chain id
            Messages.ETH,
            1_000_000_00, // 1 ether
            deployer,
            abi.encode("suiAddress")
        );

        bridge.bridgeToSui(Messages.ETH, 1 ether, abi.encode("suiAddress"), 0);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 1 ether);
        assertEq(IERC20(wETH).balanceOf(deployer), balance - 1 ether);
        assertEq(bridge.nonces(Messages.TOKEN_TRANSFER), 1);
    }

    function testBridgeEthToSui() public {
        changePrank(deployer);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 0);
        uint256 balance = deployer.balance;

        // assert emitted event
        vm.expectEmit(true, true, true, false);
        emit ISuiBridge.TokensBridgedToSui(
            TestChainID,
            0, // nonce
            0, // destination chain id
            Messages.ETH,
            1_000_000_00, // 1 ether
            deployer,
            abi.encode("suiAddress")
        );

        bridge.bridgeETHToSui{value: 1 ether}(abi.encode("suiAddress"), 0);
        assertEq(IERC20(wETH).balanceOf(address(vault)), 1 ether);
        assertEq(deployer.balance, balance - 1 ether);
        assertEq(bridge.nonces(Messages.TOKEN_TRANSFER), 1);
    }

    function testEthToSuiDecimalConversion() public {
        // ETH
        assertEq(IERC20Metadata(wETH).decimals(), 18);
        uint256 ethAmount = 10 ether;
        uint64 suiAmount = bridge.adjustDecimalsForSuiCoin(Messages.ETH, ethAmount, 18);
        assertEq(suiAmount, 10_000_000_00); // 10 * 10 ^ 8

        // USDC
        assertEq(IERC20Metadata(USDC).decimals(), 6);
        ethAmount = 50_000_000; // 50 USDC
        suiAmount = bridge.adjustDecimalsForSuiCoin(Messages.USDC, ethAmount, 6);
        assertEq(suiAmount, ethAmount);

        // USDT
        assertEq(IERC20Metadata(USDT).decimals(), 6);
        ethAmount = 60_000_000; // 60 USDT
        suiAmount = bridge.adjustDecimalsForSuiCoin(Messages.USDT, ethAmount, 6);
        assertEq(suiAmount, ethAmount);

        // BTC
        assertEq(IERC20Metadata(wBTC).decimals(), 8);
        ethAmount = 2_00_000_000; // 2 BTC
        suiAmount = bridge.adjustDecimalsForSuiCoin(Messages.BTC, ethAmount, 8);
        assertEq(suiAmount, ethAmount);
    }

    function testSuiToEthDecimalConversion() public {
        // ETH
        assertEq(IERC20Metadata(wETH).decimals(), 18);
        uint64 suiAmount = 11_000_000_00; // 11 eth
        uint256 ethAmount = bridge.adjustDecimalsForErc20(Messages.ETH, suiAmount, 18);
        assertEq(ethAmount, 11 ether);

        // USDC
        assertEq(IERC20Metadata(USDC).decimals(), 6);
        suiAmount = 50_000_000; // 50 USDC
        ethAmount = bridge.adjustDecimalsForErc20(Messages.USDC, suiAmount, 6);
        assertEq(suiAmount, ethAmount);

        // USDT
        assertEq(IERC20Metadata(USDT).decimals(), 6);
        suiAmount = 50_000_000; // 50 USDT
        ethAmount = bridge.adjustDecimalsForErc20(Messages.USDT, suiAmount, 6);
        assertEq(suiAmount, ethAmount);

        // BTC
        assertEq(IERC20Metadata(wBTC).decimals(), 8);
        suiAmount = 3_000_000_00; // 3 BTC
        ethAmount = bridge.adjustDecimalsForErc20(Messages.BTC, suiAmount, 8);
        assertEq(suiAmount, ethAmount);
    }

    // TODO:
    function testUpgradeBridge() public {}
}
