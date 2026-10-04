// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IVault.sol";
import "./PriceOracleAdapter.sol";
import "./RewardDistributor.sol";

/**
 * @title VaultCore
 * @notice Yield-generating liquidity vault allowing users to deposit ETH and receive yield-bearing shares.
 * @dev INTENTIONAL VULNERABILITIES FOR ZYRON SECURITY DEMONSTRATION:
 *      1. CRITICAL (SWC-107): State-change after low-level external call in withdraw().
 *         Sends native ETH before zeroing/updating internal sharesOf balance mapping.
 *      2. HIGH (SWC-118): Unprotected initialize() function lacking initialization modifier.
 *         Allows attacker to re-initialize governance and oracle parameters.
 *      3. FALSE POSITIVE CANDIDATE: safeEmergencyWithdraw() includes a reentrancy mutex.
 *         Static AST scanners may flag the external call, but the Zyron Virtual Sandbox
 *         proves execution safely reverts with "LOCKED" (PROVEN_FALSE_POSITIVE).
 */
contract VaultCore is IVault {
    string public constant name = "Zyron Yield Vault";
    string public constant symbol = "zyYIELD";

    address public owner;
    PriceOracleAdapter public oracle;
    RewardDistributor public distributor;

    mapping(address => uint256) public sharesOf;
    uint256 public totalVaultShares;

    // Mutex for safe withdrawal path
    bool private _locked;

    modifier nonReentrant() {
        require(!_locked, "LOCKED");
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    bool public initialized;

    /**
     * @notice Initialize protocol dependencies
     * @dev REMEDIATION: Protected against unauthorized or repeated initialization.
     */
    function initialize(address _oracle, address _distributor) external onlyOwner {
        require(!initialized, "ALREADY_INITIALIZED");
        initialized = true;
        oracle = PriceOracleAdapter(_oracle);
        distributor = RewardDistributor(_distributor);
    }

    /**
     * @notice Deposit native ETH into the vault and mint proportional shares
     */
    function deposit() external payable override returns (uint256 shares) {
        require(msg.value > 0, "ZERO_DEPOSIT");

        if (totalVaultShares == 0) {
            shares = msg.value;
        } else {
            shares = (msg.value * totalVaultShares) / (address(this).balance - msg.value);
        }

        require(shares > 0, "ZERO_SHARES");

        sharesOf[msg.sender] += shares;
        totalVaultShares += shares;

        emit Deposit(msg.sender, msg.value, shares);
    }

    /**
     * @notice Withdraw assets from the vault by redeeming shares
     * @dev REMEDIATION: Checks-Effects-Interactions pattern implemented and nonReentrant modifier added.
     *      Internal shares mapping and total shares are deducted BEFORE external transfer.
     */
    function withdraw(uint256 shares) external override nonReentrant returns (uint256 payout) {
        require(shares > 0 && sharesOf[msg.sender] >= shares, "INSUFFICIENT_SHARES");

        payout = (shares * address(this).balance) / totalVaultShares;

        // State update happens before external call
        sharesOf[msg.sender] -= shares;
        totalVaultShares -= shares;

        (bool success, ) = msg.sender.call{value: payout}("");
        require(success, "ETH_TRANSFER_FAILED");

        emit Withdraw(msg.sender, payout, shares);
    }

    /**
     * @notice Emergency withdrawal path with mutex protection
     * @dev FALSE POSITIVE TEST CASE: Protected by nonReentrant modifier and Checks-Effects-Interactions.
     *      Zyron's autonomous EVM sandbox will simulate recursive attacks here and confirm
     *      that the reentrancy attempt reverts with "LOCKED", proving it a FALSE POSITIVE.
     */
    function safeEmergencyWithdraw(uint256 shares) external nonReentrant returns (uint256 payout) {
        require(shares > 0 && sharesOf[msg.sender] >= shares, "INSUFFICIENT_SHARES");

        payout = (shares * address(this).balance) / totalVaultShares;

        // Checks-Effects-Interactions: state cleared BEFORE external transfer
        sharesOf[msg.sender] -= shares;
        totalVaultShares -= shares;

        (bool success, ) = msg.sender.call{value: payout}("");
        require(success, "TRANSFER_FAILED");

        emit Withdraw(msg.sender, payout, shares);
    }

    function totalAssets() external view override returns (uint256) {
        return address(this).balance;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return sharesOf[account];
    }

    receive() external payable {}
}
