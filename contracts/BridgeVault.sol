// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWETH9.sol";
import "./interfaces/IBridgeVault.sol";

/// @title BridgeVault
/// @dev A contract that acts as a vault for transferring ERC20 tokens and ETH. It allows the owner to transfer ERC20 tokens and ETH to a target address. The contract also supports unwrapping WETH (Wrapped Ether) and transferring the unwrapped ETH.
contract BridgeVault is Ownable, IBridgeVault {
    // The WETH address
    IWETH9 public immutable wETH;

    /// @dev Constructor function for the BridgeVault contract.
    /// @param _wETH The address of the Wrapped Ether (WETH) contract.
    constructor(address _wETH) Ownable(msg.sender) {
        // Set the WETH address
        wETH = IWETH9(_wETH);
    }

    /// @dev Transfers ERC20 tokens from the contract to a target address. Only the owner of the contract can call this function.
    /// @param tokenAddress The address of the ERC20 token.
    /// @param targetAddress The address to transfer the tokens to.
    /// @param amount The amount of tokens to transfer.
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

    /// @dev Transfers ETH from the contract to a target address.  Only the owner of the contract can call this function.
    /// @param targetAddress The address to transfer the ETH to.
    /// @param amount The amount of ETH to transfer.
    function transferETH(address payable targetAddress, uint256 amount)
        external
        override
        onlyOwner
    {
        // Unwrap the WETH
        wETH.withdraw(amount);

        // Transfer the unwrapped ETH to the target address
        targetAddress.transfer(amount);
    }

    // These are needed to receive ETH when unwrapping WETH
    receive() external payable {}

    fallback() external payable {}
}
