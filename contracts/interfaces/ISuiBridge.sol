// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISuiBridge {
    function submitMessage(bytes memory message) external;

    function transferOwnership(address newOwner) external;

    event TokensBridgedToSui(address tokenAddress, address targetAddress, uint256 amount);
}
