// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

contract BridgeBaseFuzzTest is Test {

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