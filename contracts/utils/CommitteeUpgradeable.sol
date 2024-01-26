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
        verifySignaturesAndNonce(message, signatures, BridgeMessage.BRIDGE_UPGRADE)
    {
        // decode the upgrade payload
        (address implementationAddress, bytes memory callData) =
            BridgeMessage.decodeUpgradePayload(message.payload);

        // authorize upgrade
        _upgradeAuthorized = true;
        // upgrade contract
        upgradeToAndCall(implementationAddress, callData);
        // reset upgrade authorization
        _upgradeAuthorized = false;
    }
}
