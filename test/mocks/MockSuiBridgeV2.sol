// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../contracts/SuiBridge.sol";

contract MockSuiBridgeV2 is SuiBridge {
    uint8 public mock;

    function initializeV2() external {
        _pause();
    }

    function newMockFunction(bool _pausing) external {
        if (_pausing) {
            _pause();
        } else {
            _unpause();
        }
    }

    function newerMockFunction(bool _pausing, uint8 _mock) external {
        mock = _mock;
        if (_pausing) {
            _pause();
        } else {
            _unpause();
        }
    }

    function test() external view {}
}
