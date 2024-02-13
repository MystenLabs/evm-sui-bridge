// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Utils
/// @notice A library to provide utility functions
/// @dev This library is used to provide utility functions
library Utils {
    // Define a function to calculate the converted amount based on the decimals
    function calculateConvertedAmount(uint8 ethDecimal, uint8 suiDecimal, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        uint256 convertedAmount;
        if (ethDecimal > suiDecimal) {
            // Difference in decimal places
            uint256 factor = 10 ** (ethDecimal - suiDecimal);
            convertedAmount = amount * factor;
        } else {
            // Difference in decimal places
            uint256 factor = 10 ** (suiDecimal - ethDecimal);
            convertedAmount = amount / factor;
        }
        return convertedAmount;
    }
}
