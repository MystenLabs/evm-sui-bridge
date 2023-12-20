pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

        // Get the token contract instance
        IERC20 token = IERC20(tokenAddress);

        // Transfer the tokens from the contract to the target address
        bool success = token.transfer(targetAddress, amount);

        // Check that the transfer was successful
        require(success, "Transfer failed");
    }
}
