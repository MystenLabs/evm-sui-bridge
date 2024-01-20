// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./interfaces/IBridgeLimiter.sol";
import "./interfaces/IBridgeTokens.sol";
import "./utils/CommitteeUpgradeable.sol";

contract BridgeLimiter is IBridgeLimiter, CommitteeUpgradeable, OwnableUpgradeable {
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
        oldestHourTimestamp = uint32(block.timestamp / 1 hours);
        totalLimit = _totalLimit;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function willAmountExceedLimit(uint8 tokenId, uint256 amount) public view returns (bool) {
        uint256 windowAmount = calculateWindowAmount();
        uint256 USDAmount = calculateAmountInUSD(tokenId, amount);
        return windowAmount + USDAmount > totalLimit;
    }

    function calculateWindowAmount() public view returns (uint256 total) {
        uint32 currentHour = uint32(block.timestamp / 1 hours);
        // aggregate the last 24 hours
        for (uint32 i = 0; i < 24; i++) {
            total += hourlyTransferAmount[currentHour - i];
        }
        return total;
    }

    function calculateAmountInUSD(uint8 tokenId, uint256 amount) public view returns (uint256) {
        // get the token address
        address tokenAddress = tokens.getAddress(tokenId);
        // get the decimals
        uint8 decimals = IERC20Metadata(tokenAddress).decimals();

        return amount * assetPrices[tokenId] / (10 ** decimals);
    }

    /* ========== EXTERNAL FUNCTIONS ========== */

    function updateBridgeTransfers(uint8 tokenId, uint256 amount) external override onlyOwner {
        require(amount > 0, "BridgeLimiter: amount must be greater than 0");
        require(
            !willAmountExceedLimit(tokenId, amount),
            "BridgeLimiter: amount exceeds rolling window limit"
        );

        uint32 currentHour = uint32(block.timestamp / 1 hours);

        // garbage collect most recently expired hour if window is moving
        if (hourlyTransferAmount[currentHour] == 0 && oldestHourTimestamp < currentHour - 24) {
            garbageCollectHourlyTransferAmount(currentHour - 25, currentHour - 25);
        }

        // update hourly transfers
        hourlyTransferAmount[currentHour] += calculateAmountInUSD(tokenId, amount);
    }

    function garbageCollectHourlyTransferAmount(uint32 startHour, uint32 endHour) public {
        uint32 windowStart = uint32(block.timestamp / 1 hours) - 24;
        require(
            startHour >= oldestHourTimestamp, "BridgeLimiter: hourTimestamp must be in the past"
        );
        require(startHour < windowStart, "BridgeLimiter: start must be before current window");
        require(endHour < windowStart, "BridgeLimiter: end must be before current window");

        for (uint32 i = startHour; i <= endHour; i++) {
            if (hourlyTransferAmount[i] > 0) delete hourlyTransferAmount[i];
        }

        // update oldest hour if current oldest hour was garbage collected
        if (startHour == oldestHourTimestamp) {
            oldestHourTimestamp = endHour + 1;
        }
    }

    function updateAssetPriceWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifySignatures(message, signatures, BridgeMessage.UPDATE_ASSET_PRICE)
    {
        // decode the update asset payload
        (uint8 tokenId, uint256 price) = BridgeMessage.decodeUpdateAssetPayload(message.payload);

        // update the asset price
        assetPrices[tokenId] = price;
    }

    function updateLimitWithSignatures(
        bytes[] memory signatures,
        BridgeMessage.Message memory message
    )
        external
        nonReentrant
        verifySignatures(message, signatures, BridgeMessage.UPDATE_BRIDGE_LIMIT)
    {
        // decode the update limit payload
        (uint256 newLimit) = BridgeMessage.decodeUpdateLimitPayload(message.payload);

        // update the limit
        totalLimit = newLimit;
    }
}
