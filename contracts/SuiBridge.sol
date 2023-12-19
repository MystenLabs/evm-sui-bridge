pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SuiBridge is OwnableUpgradeable {
    function initialize() external initializer {
        __Ownable_init();
    }

    function submitMessage(bytes memory message) external onlyOwner {
        // TODO: DECODE MESSAGE AND CALL CORRECT FUNCTION
    }
}
