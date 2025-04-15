// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IERC7914 {
    function transferFromNative(address from, address recipient, uint256 amount) external returns (bool);
    function approveNative(address spender, uint256 amount) external returns (bool);
}
