// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for WETH9
/// @notice This interface defines the functions for interacting with the WETH9 contract. Users can deposit ether to get wrapped ether and withdraw wrapped ether to get ether.
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    /// @dev This function allows users to deposit ether and receive wrapped ether tokens in return.
    /// @dev The amount of ether to be deposited should be sent along with the function call.
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    /// @dev This function allows users to withdraw a specified amount of wrapped ether and receive ether in return.
    /// @param wad The amount of wrapped ether to be withdrawn.
    function withdraw(uint256 wad) external;
}
