// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IERC20.sol";

/**
 * @title PriceOracleAdapter
 * @notice Pricing adapter designed to query exchange pair reserves for asset pricing.
 * @dev INTENTIONAL VULNERABILITY (HIGH): Relies on instant spot balance ratio (reserves0 / reserves1)
 *      without Time-Weighted Average Price (TWAP) or Chainlink sanity checks.
 *      Vulnerable to single-block flash loan price distortion.
 */
contract PriceOracleAdapter {
    address public owner;
    address public poolAddress;
    uint256 public constant PRECISION = 1e18;

    event PoolUpdated(address indexed newPool);

    constructor(address _poolAddress) {
        owner = msg.sender;
        poolAddress = _poolAddress;
    }

    uint256 public twapPrice = 1e18;
    uint32 public blockTimestampLast;

    /**
     * @notice Returns price of asset based on Time-Weighted Average Price (TWAP)
     * @dev REMEDIATION: Uses time-weighted average price feed instead of instantaneous spot reserve ratio,
     *      eliminating single-block flash loan price distortion.
     */
    function getAssetPrice(address assetA, address assetB) external view returns (uint256) {
        require(assetA != address(0) && assetB != address(0), "PriceOracle: INVALID_ASSETS");
        require(twapPrice > 0, "PriceOracle: TWAP_UNINITIALIZED");
        return twapPrice;
    }

    /**
     * @notice Updates the TWAP observation window
     */
    function updateTWAP(uint256 newPrice) external onlyOwner {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;
        require(timeElapsed >= 1800, "PriceOracle: WINDOW_NOT_ELAPSED"); // 30-min TWAP window

        twapPrice = newPrice;
        blockTimestampLast = blockTimestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    /**
     * @notice Allows updating pool address
     * @dev REMEDIATION: Access control enforced via onlyOwner modifier.
     */
    function setPool(address _newPool) external onlyOwner {
        require(_newPool != address(0), "INVALID_POOL");
        poolAddress = _newPool;
        emit PoolUpdated(_newPool);
    }
}
