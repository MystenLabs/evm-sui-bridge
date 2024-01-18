// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../contracts/SuiBridge.sol";

contract MockSuiBridgeV2 is SuiBridge {
    function initializeV2() external {
        _pause();
    }

    function newMockFunction() external {
        _unpause();
    }
}
