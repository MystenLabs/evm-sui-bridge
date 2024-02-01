// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract BridgeBaseFuzzTest is Test {
    address committeeMemberA;
    address committeeMemberB;
    address committeeMemberC;
    address committeeMemberD;
    address committeeMemberE;

    uint256 committeeMemberPkA;
    uint256 committeeMemberPkB;
    uint256 committeeMemberPkC;
    uint256 committeeMemberPkD;
    uint256 committeeMemberPkE;

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
    uint256 totalLimit = 10000000000;

    BridgeCommittee public committee;
    SuiBridge public bridge;
    BridgeVault public vault;
    BridgeLimiter public limiter;
    BridgeTokens public tokens;

    function setUpBridgeTest() public {
        vm.createSelectFork(
            string.concat(
                "https://mainnet.infura.io/v3/",
                vm.envString("INFURA_API_KEY")
            )
        );
        (committeeMemberA, committeeMemberPkA) = makeAddrAndKey("a");
        (committeeMemberB, committeeMemberPkB) = makeAddrAndKey("b");
        (committeeMemberC, committeeMemberPkC) = makeAddrAndKey("c");
        (committeeMemberD, committeeMemberPkD) = makeAddrAndKey("d");
        (committeeMemberE, committeeMemberPkE) = makeAddrAndKey("e");
        bridgerA = makeAddr("bridgerA");
        bridgerB = makeAddr("bridgerB");
        bridgerC = makeAddr("bridgerC");
        vm.deal(committeeMemberA, 1 ether);
        vm.deal(committeeMemberB, 1 ether);
        vm.deal(committeeMemberC, 1 ether);
        vm.deal(committeeMemberD, 1 ether);
        vm.deal(committeeMemberE, 1 ether);
        vm.deal(bridgerA, 1 ether);
        vm.deal(bridgerB, 1 ether);
        deployer = address(1);
        vm.startPrank(deployer);
        address[] memory _committee = new address[](5);
        uint16[] memory _stake = new uint16[](5);
        _committee[0] = committeeMemberA;
        _committee[1] = committeeMemberB;
        _committee[2] = committeeMemberC;
        _committee[3] = committeeMemberD;
        _committee[4] = committeeMemberE;
        _stake[0] = 1000;
        _stake[1] = 1000;
        _stake[2] = 1000;
        _stake[3] = 2002;
        _stake[4] = 4998;
        committee = new BridgeCommittee();

        // Test fail initialize: committee and stake arrays must be of the same length
        address[] memory _committeeNotSameLength = new address[](5);
        _committeeNotSameLength[0] = committeeMemberA;
        _committeeNotSameLength[1] = committeeMemberB;
        _committeeNotSameLength[2] = committeeMemberC;
        _committeeNotSameLength[3] = committeeMemberD;
        _committeeNotSameLength[4] = committeeMemberE;

        uint16[] memory _stakeNotSameLength = new uint16[](4);
        _stakeNotSameLength[0] = 1000;
        _stakeNotSameLength[1] = 1000;
        _stakeNotSameLength[2] = 1000;
        _stakeNotSameLength[3] = 2002;

        vm.expectRevert(
            bytes(
                "BridgeCommittee: Committee and stake arrays must be of the same length"
            )
        );
        committee.initialize(_committeeNotSameLength, _stakeNotSameLength);

        // Test fail initialize: Committee Duplicate Committee Member
        address[] memory _committeeDuplicateCommitteeMember = new address[](5);
        _committeeDuplicateCommitteeMember[0] = committeeMemberA;
        _committeeDuplicateCommitteeMember[1] = committeeMemberB;
        _committeeDuplicateCommitteeMember[2] = committeeMemberC;
        _committeeDuplicateCommitteeMember[3] = committeeMemberD;
        _committeeDuplicateCommitteeMember[4] = committeeMemberA;

        uint16[] memory _stakeDuplicateCommitteeMember = new uint16[](5);
        _stakeDuplicateCommitteeMember[0] = 1000;
        _stakeDuplicateCommitteeMember[1] = 1000;
        _stakeDuplicateCommitteeMember[2] = 1000;
        _stakeDuplicateCommitteeMember[3] = 2002;
        _stakeDuplicateCommitteeMember[4] = 1000;

        vm.expectRevert(bytes("BridgeCommittee: Duplicate committee member"));
        committee.initialize(
            _committeeDuplicateCommitteeMember,
            _stakeDuplicateCommitteeMember
        );

        // Test fail initialize: Total Stake Must Be 10000
        address[] memory _committeeTotalStakeMustBe10000 = new address[](4);
        _committeeTotalStakeMustBe10000[0] = committeeMemberA;
        _committeeTotalStakeMustBe10000[1] = committeeMemberB;
        _committeeTotalStakeMustBe10000[2] = committeeMemberC;
        _committeeTotalStakeMustBe10000[3] = committeeMemberD;

        uint16[] memory _stakeTotalStakeMustBe10000 = new uint16[](4);
        _stakeTotalStakeMustBe10000[0] = 1000;
        _stakeTotalStakeMustBe10000[1] = 1000;
        _stakeTotalStakeMustBe10000[2] = 1000;
        _stakeTotalStakeMustBe10000[3] = 2000;

        vm.expectRevert(bytes("BridgeCommittee: Total stake must be 10000"));
        committee.initialize(
            _committeeTotalStakeMustBe10000,
            _stakeTotalStakeMustBe10000
        );

        committee.initialize(_committee, _stake);
        vault = new BridgeVault(wETH);
        address[] memory _supportedTokens = new address[](4);
        _supportedTokens[0] = wBTC;
        _supportedTokens[1] = wETH;
        _supportedTokens[2] = USDC;
        _supportedTokens[3] = USDT;
        tokens = new BridgeTokens(_supportedTokens);
        uint256[] memory assetPrices = new uint256[](4);
        assetPrices[0] = SUI_PRICE;
        assetPrices[1] = BTC_PRICE;
        assetPrices[2] = ETH_PRICE;
        assetPrices[3] = USDC_PRICE;
        limiter = new BridgeLimiter();
        limiter.initialize(
            address(committee),
            address(tokens),
            assetPrices,
            totalLimit
        );
        bridge = new SuiBridge();
        bridge.initialize(
            address(committee),
            address(tokens),
            address(vault),
            address(limiter),
            wETH,
            chainID
        );
        vault.transferOwnership(address(bridge));
        limiter.transferOwnership(address(bridge));
        tokens.transferOwnership(address(bridge));
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

    // Helper function to get the signature components from an address
    function getSignature(
        bytes32 digest,
        uint256 privateKey
    ) internal pure returns (bytes memory) {
        // r and s are the outputs of the ECDSA signature
        // r,s and v are packed into the signature. It should be 65 bytes: 32 + 32 + 1
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // pack v, r, s into 65bytes signature
        return abi.encodePacked(r, s, v);
    }
}
