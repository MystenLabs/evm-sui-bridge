pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BridgeVault is Ownable {
    address public bridge;

    constructor(address _bridge) {
        bridge = _bridge;
        _transferOwnership(msg.sender);
    }

    function transferTokens(address tokenAddress, address targetAddress, uint256 amount)
        external
        onlyOwner
    {
        // TODO: use OZ ERC20 transfer amount to targetAddress
    }
}
