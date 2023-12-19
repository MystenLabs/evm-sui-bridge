pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SuiBridge is Ownable {
    function initialize() external initializer {
        __Ownable_init();
        __Pausable_init();
    }

    function transferTokens(address tokenAddress, address targetAddress, uint256 amount)
        external
        onlyOwner
    {
        // TODO: use OZ ERC20 transfer amount to targetAddress
    }
}
