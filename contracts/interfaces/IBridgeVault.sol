// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBridgeVault {
    function transferERC20(address tokenAddress, address targetAddress, uint256 amount) external;

    function transferETH(address payable targetAddress, uint256 amount) external;
}
