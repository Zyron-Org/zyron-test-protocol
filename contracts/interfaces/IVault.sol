// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVault {
    event Deposit(address indexed user, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, uint256 amount, uint256 shares);

    function deposit() external payable returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function totalAssets() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}
