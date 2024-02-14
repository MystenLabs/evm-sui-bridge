// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ConversionUtils
/// @notice A library to provide utility functions
/// @dev This library is used to provide utility functions
library ConversionUtils {
    
    /// @notice Ensure the decimals are valid
    /// @param ethDecimal The decimal of the ETH token
    /// @param suiDecimal The decimal of the SUI token
    modifier validDecimals(uint8 ethDecimal, uint8 suiDecimal) {
        require(ethDecimal <= 19, "ConversionUtils: Invalid ETH decimal");
        require(suiDecimal <= 19, "ConversionUtils: Invalid SUI decimal");
        _;
    }

    /// @notice Calculate the converted amount from ETH to SUI decimal
    /// @param ethDecimal The decimal of the ETH token
    /// @param suiDecimal The decimal of the SUI token
    /// @param amount The amount to convert
    /// @return The converted amount
    function calculateEthToSuiConvertedAmount(uint8 ethDecimal, uint8 suiDecimal, uint256 amount)
        internal
        pure
        validDecimals(ethDecimal, suiDecimal)
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

    /// @notice Calculate the converted amount from SUI to ETH decimal
    /// @param ethDecimal The decimal of the ETH token
    /// @param suiDecimal The decimal of the SUI token
    /// @param amount The amount to convert
    /// @return The converted amount
    function calculateSuiToEthConvertedAmount(uint8 ethDecimal, uint8 suiDecimal, uint256 amount)
        internal
        pure
        validDecimals(ethDecimal, suiDecimal)
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
