// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

interface ICurrency {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function owner() external view returns (address owner);
}
