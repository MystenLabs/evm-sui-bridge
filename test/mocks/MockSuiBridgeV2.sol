// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/SuiBridge.sol";

contract MockSuiBridgeV2 is SuiBridge {
    function initializeV2() external {
        _pause();
    }

    function newMockFunction() external {
        _unpause();
    }

    function test() external view {}
}
