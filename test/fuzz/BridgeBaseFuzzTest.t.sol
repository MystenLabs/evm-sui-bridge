// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../contracts/BridgeCommittee.sol";
import "../../contracts/BridgeVault.sol";
import "../../contracts/BridgeLimiter.sol";
import "../../contracts/SuiBridge.sol";
import "../../contracts/BridgeTokens.sol";

contract BridgeBaseFuzzTest is Test {
    address committeeMemeberAddressA;
    address committeeMemeberAddressB;
    address committeeMemeberAddressC;
    address committeeMemeberAddressD;
    address committeeMemeberAddressE;

    uint256 committeeMemeberPkA;
    uint256 committeeMemeberPkB;
    uint256 committeeMemeberPkC;
    uint256 committeeMemeberPkD;
    uint256 committeeMemeberPkE;

    uint16 public committeeMemeberStakeA = 1000;
    uint16 public committeeMemeberStakeB = 1000;
    uint16 public committeeMemeberStakeC = 1000;
    uint16 public committeeMemeberStakeD = 2002;
    uint16 public committeeMemeberStakeE = 4998;

    uint8 public constant N = 5;
    address[] _committeeMemebers = new address[](N);
    uint16[] _stake = new uint16[](N);
    uint256[] signers = new uint256[](N);

    address bridgerA;
    address bridgerB;
    address bridgerC;

    address deployer;

    address wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address wBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    address USDCWhale = 0x51eDF02152EBfb338e03E30d65C15fBf06cc9ECC;

    uint256 SUI_PRICE = 12800;
    uint256 BTC_PRICE = 432518900;
    uint256 ETH_PRICE = 25969600;
    uint256 USDC_PRICE = 10000;

    uint8 public chainID = 99;
    uint64 totalLimit = 10000000000;

    BridgeCommittee public bridgeCommittee;
    SuiBridge public suiBridge;
    BridgeVault public bridgeVault;
    BridgeLimiter public bridgeLimiter;
    BridgeTokens public bridgeTokens;

    function setUpBridgeFuzzTest() public {
        vm.createSelectFork(
            string.concat(
                "https://mainnet.infura.io/v3/",
                vm.envString("INFURA_API_KEY")
            )
        );

        (committeeMemeberAddressA, committeeMemeberPkA) = makeAddrAndKey("a");
        (committeeMemeberAddressB, committeeMemeberPkB) = makeAddrAndKey("b");
        (committeeMemeberAddressC, committeeMemeberPkC) = makeAddrAndKey("c");
        (committeeMemeberAddressD, committeeMemeberPkD) = makeAddrAndKey("d");
        (committeeMemeberAddressE, committeeMemeberPkE) = makeAddrAndKey("e");

        bridgerA = makeAddr("bridgerA");
        bridgerB = makeAddr("bridgerB");
        bridgerC = makeAddr("bridgerC");

        vm.deal(committeeMemeberAddressA, 1 ether);
        vm.deal(committeeMemeberAddressB, 1 ether);
        vm.deal(committeeMemeberAddressC, 1 ether);
        vm.deal(committeeMemeberAddressD, 1 ether);
        vm.deal(committeeMemeberAddressE, 1 ether);

        vm.deal(bridgerA, 1 ether);
        vm.deal(bridgerB, 1 ether);

        deployer = address(1);
        vm.startPrank(deployer);

        _committeeMemebers[0] = committeeMemeberAddressA;
        _committeeMemebers[1] = committeeMemeberAddressB;
        _committeeMemebers[2] = committeeMemeberAddressC;
        _committeeMemebers[3] = committeeMemeberAddressD;
        _committeeMemebers[4] = committeeMemeberAddressE;

        _stake[0] = 1000;
        _stake[1] = 1000;
        _stake[2] = 1000;
        _stake[3] = 2002;
        _stake[4] = 4998;

        signers[0] = committeeMemeberPkA;
        signers[1] = committeeMemeberPkB;
        signers[2] = committeeMemeberPkC;
        signers[3] = committeeMemeberPkD;
        signers[4] = committeeMemeberPkE;

        bridgeCommittee = new BridgeCommittee();
        bridgeCommittee.initialize(_committeeMemebers, _stake, chainID);

        bridgeVault = new BridgeVault(wETH);
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

        bridgeLimiter = new BridgeLimiter();
        bridgeLimiter.initialize(
            address(bridgeCommittee),
            address(bridgeTokens),
            assetPrices,
            totalLimit
        );

        uint8[] memory _supportedDestinationChains = new uint8[](1);
        _supportedDestinationChains[0] = 0;

        suiBridge = new SuiBridge();
        suiBridge.initialize(
            address(bridgeCommittee),
            address(bridgeTokens),
            address(bridgeVault),
            address(bridgeLimiter),
            wETH,
            _supportedDestinationChains
        );

        bridgeVault.transferOwnership(address(suiBridge));
        bridgeLimiter.transferOwnership(address(suiBridge));
        bridgeTokens.transferOwnership(address(suiBridge));
    }

    function testMock() public {}

    // Helper function to get the signature components from an address
    function getSignature(
        bytes32 digest,
        uint256 privateKey
    ) public pure returns (bytes memory) {
        // r and s are the outputs of the ECDSA signature
        // r,s and v are packed into the signature. It should be 65 bytes: 32 + 32 + 1
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // pack v, r, s into 65bytes signature
        return abi.encodePacked(r, s, v);
    }
    
}
