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

    /**
     * @notice Returns price of asset based on instantaneous reserve ratio
     * @dev Flawed: vulnerable to spot price manipulation via flash swaps
     */
    function getAssetPrice(address assetA, address assetB) external view returns (uint256) {
        uint256 reserveA = IERC20(assetA).balanceOf(poolAddress);
        uint256 reserveB = IERC20(assetB).balanceOf(poolAddress);

        require(reserveB > 0, "PriceOracle: ZERO_RESERVES");

        // Vulnerable spot price calculation:
        return (reserveA * PRECISION) / reserveB;
    }

    /**
     * @notice Allows updating pool address
     */
    function setPool(address _newPool) external {
        // Missing onlyOwner access control check: anyone can redirect oracle pool!
        poolAddress = _newPool;
        emit PoolUpdated(_newPool);
    }
}
