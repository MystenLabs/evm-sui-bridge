// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBridgeVault {
    function transferERC20(address tokenAddress, address targetAddress, uint256 amount) external;
}
