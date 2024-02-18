// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IBridgeCommittee.sol";
import "./MessageVerifier.sol";

abstract contract CommitteeUpgradeable is
    UUPSUpgradeable,
    MessageVerifier,
    ReentrancyGuardUpgradeable
{
    bool private _upgradeAuthorized;

    function __CommitteeUpgradeable_init(address _committee) internal onlyInitializing {
        __ReentrancyGuard_init();
        __MessageVerifier_init(_committee);
        committee = IBridgeCommittee(_committee);
    }

    function _authorizeUpgrade(address) internal view override {
        require(_upgradeAuthorized, "SuiBridge: Unauthorized upgrade");
    }

    function upgradeWithSignatures(bytes[] memory signatures, BridgeMessage.Message memory message)
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.UPGRADE)
    {
        // decode the upgrade payload
        (address proxy, address implementation, bytes memory callData) =
            BridgeMessage.decodeUpgradePayload(message.payload);

        // verify proxy address
        require(proxy == address(this), "SuiBridge: Invalid proxy address");

        // authorize upgrade
        _upgradeAuthorized = true;
        // upgrade contract
        upgradeToAndCall(implementation, callData); // Upgraded event emitted with new implementation address
        // reset upgrade authorization
        _upgradeAuthorized = false;
    }
}
