// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IBridgeLimiter.sol";
import "./interfaces/IBridgeTokens.sol";
import "./utils/CommitteeUpgradeable.sol";

contract BridgeLimiter is IBridgeLimiter, CommitteeUpgradeable, OwnableUpgradeable {
    uint32 public constant MAX_HOURS_TO_GC_PER_CALL = 720;

    /* ========== STATE VARIABLES ========== */

    IBridgeTokens public tokens;
    // hour timestamp => total amount bridged (on a given hour)
    mapping(uint32 => uint256) public hourlyTransferAmount;
    // token id => token price in USD (4 decimal precision) (e.g. 1 ETH = 2000 USD => 20000000)
    mapping(uint8 => uint256) public assetPrices;
    // total limit in USD (4 decimal precision) (e.g. 10000000 => 1000 USD)
    uint256 public totalLimit;
    uint32 public oldestHourTimestamp;

    /* ========== INITIALIZER ========== */

    /// @dev Initializes the BridgeLimiter contract.
    /// @param _committee The address of the committee contract.
    /// @param _tokens The address of the BridgeTokens contract.
    /// @param _assetPrices An array of asset prices.
    /// @param _totalLimit The total limit for the bridge.
    function initialize(
        address _committee,
        address _tokens,
        uint256[] memory _assetPrices,
        uint256 _totalLimit
    ) external initializer {
        __CommitteeUpgradeable_init(_committee);
        __Ownable_init(msg.sender);
        tokens = IBridgeTokens(_tokens);
        for (uint8 i = 0; i < _assetPrices.length; i++) {
            assetPrices[i] = _assetPrices[i];
        }
        oldestHourTimestamp = currentHour();
        totalLimit = _totalLimit;
    }

    /* ========== VIEW FUNCTIONS ========== */

    /// @dev Checks if the total amount, including the given `amount` in USD, will exceed the `totalLimit`.
    /// @param tokenId The ID of the token.
    /// @param amount The amount of the token.
    /// @return A boolean indicating whether the total amount will exceed the limit.
    function willAmountExceedLimit(uint8 tokenId, uint256 amount)
        public
        view
        override
        returns (bool)
    {
        uint256 windowAmount = calculateWindowAmount();
        uint256 USDAmount = calculateAmountInUSD(tokenId, amount);
        return windowAmount + USDAmount > totalLimit;
    }

    function willUSDAmountExceedLimit(uint256 amount) public view returns (bool) {
        uint256 windowAmount = calculateWindowAmount();
        return windowAmount + amount > totalLimit;
    }

    /// @dev Calculates the total transfer amount within a 24-hour window.
    /// @return total The total transfer amount within the window.
    function calculateWindowAmount() public view returns (uint256 total) {
        uint32 _currentHour = currentHour();
        // aggregate the last 24 hours
        for (uint32 i = 0; i < 24; i++) {
            total += hourlyTransferAmount[_currentHour - i];
        }
        return total;
    }

    /// @dev Calculates the amount in USD for a given token and amount.
    /// @param tokenId The ID of the token.
    /// @param amount The amount of tokens.
    /// @return The amount in USD.
    function calculateAmountInUSD(uint8 tokenId, uint256 amount) public view returns (uint256) {
        // get the token address
        address tokenAddress = tokens.getAddress(tokenId);
        // get the decimals
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();

        return amount * assetPrices[tokenId] / (10 ** decimals);
    }

    function currentHour() public view returns (uint32) {
        return uint32(block.timestamp / 1 hours);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    /// @dev Updates the bridge transfers for a specific token ID and amount. Only the contract owner can call this function.
    /// Requirements:
    /// - The amount must be greater than 0.
    /// - The amount must not exceed the rolling window limit.
    /// @param tokenId The ID of the token.
    /// @param amount The amount of tokens to be transferred.
    function updateBridgeTransfers(uint8 tokenId, uint256 amount) external override onlyOwner {
        require(amount > 0, "BridgeLimiter: amount must be greater than 0");
        uint256 usdAmount = calculateAmountInUSD(tokenId, amount);
        require(
            !willUSDAmountExceedLimit(usdAmount),
            "BridgeLimiter: amount exceeds rolling window limit"
        );

        uint32 _currentHour = currentHour();

        // garbage collect most recently expired hour if possible
        if (hourlyTransferAmount[_currentHour - 25] > 0) {
            delete hourlyTransferAmount[_currentHour - 25];
        }

        // update hourly transfers
        hourlyTransferAmount[_currentHour] += usdAmount;
    }

    /// @dev Updates the asset price with the provided signatures and message.
    /// @param signatures The array of signatures for the message.
    /// @param message The BridgeMessage containing the update asset payload.
    function updateAssetPriceWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.UPDATE_ASSET_PRICE)
    {
        // decode the update asset payload
        (uint8 tokenId, uint256 price) = BridgeMessage.decodeUpdateAssetPayload(message.payload);

        // update the asset price
        assetPrices[tokenId] = price;
    }

    /// @dev Updates the bridge limit with the provided signatures and message.
    /// @param signatures The array of signatures for the message.
    /// @param message The BridgeMessage containing the update limit payload.
    function updateLimitWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifyMessageAndSignatures(message, signatures, BridgeMessage.UPDATE_BRIDGE_LIMIT)
    {
        // decode the update limit payload
        (uint256 newLimit) = BridgeMessage.decodeUpdateLimitPayload(message.payload);

        // update the limit
        totalLimit = newLimit;
    }
}
