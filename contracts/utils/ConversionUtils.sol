// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ConversionUtils
/// @notice A library to provide utility functions
/// @dev This library is used to provide utility functions
library ConversionUtils {
    // Define a function to calculate the converted amount based on the decimals
    function calculateEthToSuiConvertedAmount(uint8 ethDecimal, uint8 suiDecimal, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        if (ethDecimal == suiDecimal) {
            return amount;
        } else if (ethDecimal > suiDecimal) {
            // Difference in decimal places
            uint256 factor = 10 ** (ethDecimal - suiDecimal);
            return (amount / factor);
        } else {
            // Difference in decimal places
            uint256 factor = 10 ** (suiDecimal - ethDecimal);
            return (amount * factor);
        }
    }

    // Define a function to calculate the converted amount based on the decimals
    function calculateSuiToEthConvertedAmount(uint8 ethDecimal, uint8 suiDecimal, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        if (suiDecimal == ethDecimal) {
            return amount;
        } else if (ethDecimal > suiDecimal) {
            // Difference in decimal places
            uint256 factor = 10 ** (ethDecimal - suiDecimal);
            return (amount * factor);
        } else {
            // Difference in decimal places
            uint256 factor = 10 ** (suiDecimal - ethDecimal);
            return (amount / factor);
        }
    }
}
