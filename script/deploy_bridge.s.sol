// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
// import "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../contracts/BridgeCommittee.sol";
import "../contracts/BridgeVault.sol";
import "../contracts/BridgeTokens.sol";
import "../contracts/BridgeLimiter.sol";
import "../contracts/SuiBridge.sol";
import "../test/mocks/MockTokens.sol";

contract DeployBridge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        string memory chainID = Strings.toString(block.chainid);
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deploy_configs/", chainID, ".json");
        string memory json = vm.readFile(path);
        bytes memory bytesJson = vm.parseJson(json);
        DeployConfig memory config = abi.decode(bytesJson, (DeployConfig));

        // TODO: validate config values before deploying

        // if deploying to local network, deploy mock tokens
        if (keccak256(abi.encode(chainID)) == keccak256(abi.encode("31337"))) {
            // deploy WETH
            config.WETH = address(new WETH());

            // deploy mock tokens
            MockWBTC wBTC = new MockWBTC();
            MockUSDC USDC = new MockUSDC();

            // update config with mock addresses
            config.supportedTokens = new address[](4);
            config.supportedTokens[0] = address(0);
            config.supportedTokens[1] = address(wBTC);
            config.supportedTokens[2] = config.WETH;
            config.supportedTokens[3] = address(USDC);

            config.tokenSuiDecimals = new uint8[](4);
            config.tokenSuiDecimals[0] = 9;
            config.tokenSuiDecimals[1] = 8;
            config.tokenSuiDecimals[2] = 8;
            config.tokenSuiDecimals[3] = 6;
        }

        // deploy Bridge Committee

        // convert committeeMembers stake from uint256 to uint16[]
        uint16[] memory committeeMemberStake = new uint16[](config.committeeMemberStake.length);
        for (uint256 i; i < config.committeeMemberStake.length; i++) {
            committeeMemberStake[i] = uint16(config.committeeMemberStake[i]);
        }

        address bridgeCommittee = Upgrades.deployUUPSProxy(
            "BridgeCommittee.sol",
            abi.encodeCall(
                BridgeCommittee.initialize,
                (config.committeeMembers, committeeMemberStake, uint8(config.sourceChainId))
            )
        );

        // deploy vault

        BridgeVault vault = new BridgeVault(config.WETH);

        // deploy bridge tokens

        BridgeTokens bridgeTokens =
            new BridgeTokens(config.supportedTokens, config.tokenSuiDecimals);

        // deploy limiter

        address limiter = Upgrades.deployUUPSProxy(
            "BridgeLimiter.sol",
            abi.encodeCall(
                BridgeLimiter.initialize,
                (
                    bridgeCommittee,
                    address(bridgeTokens),
                    config.tokenPrices,
                    uint64(config.totalBridgeLimitInDollars)
                )
            )
        );

        uint8[] memory _supportedDestinationChains = new uint8[](2);
        _supportedDestinationChains[0] = 0;
        _supportedDestinationChains[1] = 1;

        // deploy Sui Bridge

        address suiBridge = Upgrades.deployUUPSProxy(
            "SuiBridge.sol",
            abi.encodeCall(
                SuiBridge.initialize,
                (
                    bridgeCommittee,
                    address(bridgeTokens),
                    address(vault),
                    limiter,
                    config.WETH,
                    _supportedDestinationChains
                )
            )
        );

        // transfer vault ownership to bridge
        vault.transferOwnership(suiBridge);
        // transfer limiter ownership to bridge
        BridgeLimiter instance = BridgeLimiter(limiter);
        instance.transferOwnership(suiBridge);
        // transfer bridge tokens ownership to bridge
        bridgeTokens.transferOwnership(suiBridge);
        vm.stopBroadcast();
    }

    function test() public {}
}

/// check the following for guidelines on updating deploy_configs and references:
/// https://book.getfoundry.sh/cheatcodes/parse-json
struct DeployConfig {
    uint256[] committeeMemberStake;
    address[] committeeMembers;
    uint256 sourceChainId;
    address[] supportedTokens;
    uint256[] tokenPrices;
    uint8[] tokenSuiDecimals;
    uint256 totalBridgeLimitInDollars;
    address WETH;
}
