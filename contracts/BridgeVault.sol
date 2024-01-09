// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IBridgeVault.sol";

contract BridgeVault is Ownable, IBridgeVault {
    // The WETH address
    IWETH9 public immutable wETH;

    constructor(address _wETH) Ownable() {
        // Set the WETH address
        wETH = IWETH9(_wETH);
    }

    function transferERC20(address tokenAddress, address targetAddress, uint256 amount)
        external
        override
        onlyOwner
    {
        // Get the token contract instance
        IERC20 token = IERC20(tokenAddress);

        // Transfer the tokens from the contract to the target address
        bool success = token.transfer(targetAddress, amount);

        // Check that the transfer was successful
        require(success, "BridgeVault: Transfer failed");
    }

    function transferETH(address payable targetAddress, uint256 amount)
        external
        override
        onlyOwner
    {
        // unwrap the WETH
        wETH.withdraw(amount);

        // TODO: check transfer success
        // Transfer the unwrapped ETH to the target address
        targetAddress.transfer(amount);
    }

    // These are needed to receive ETH when unwrapping WETH
    receive() external payable {}

    fallback() external payable {}
}
