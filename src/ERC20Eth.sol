// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC7914} from "./interfaces/IERC7914.sol";

/// @title ERC20ETH
/// @notice An ERC20 wrapper for native ETH that leverages ERC-7914 for smart wallet compatibility.
///
/// This contract allows native ETH to be used with ERC20 interfaces by implementing the ERC20 standard
/// while using ERC-7914's transferFromNative hook to move ETH from smart wallets.
///
/// Key features:
/// - Implements IERC20 interface for ETH
/// - Uses ERC-7914 for native ETH transfers from smart wallets
/// - Maintains allowances for transferFrom operations
/// - Does not track balances internally (relies on native ETH balances)
contract ERC20ETH is IERC20 {
    /// @notice Thrown when balanceOf is called, as this contract doesn't track balances internally
    /// to prevent double-entrypoint balance check bugs.
    error BalanceOfNotSupported();

    /// @notice Thrown when the contract doesn't have enough ETH to complete a transfer.
    error InsufficientTransferAmount();

    /// @notice Thrown when an ETH transfer fails.
    error TransferFailed();

    /// @notice Total supply is always 0 as this contract doesn't mint tokens.
    /// It wraps existing ETH.
    uint256 public constant override totalSupply = 0;

    /// @notice Decimals is 18, matching ETH's native decimals.
    uint8 public constant override decimals = 18;

    /// @notice Token name.
    string public override name;

    /// @notice Token symbol.
    string public override symbol;

    /// @notice Mapping of owner address to spender address to allowance amount.
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice Constructor sets the name and symbol for the token.
    constructor() {
        name = "ERC20 ETH";
        symbol = "ETH";
    }

    /// @notice This function is intentionally disabled to prevent double-entrypoint balance check bugs.
    /// Users should check ETH balances directly instead of through this contract.
    /// @return Never returns, always reverts
    function balanceOf(address) public pure override returns (uint256) {
        // capturing account balances via the token is not supported
        // to prevent double-entrypoint balance check bugs
        revert BalanceOfNotSupported();
    }

    /// @notice Sets `amount` as the allowance of `spender` over the caller's tokens.
    /// @param spender The address which will spend the funds
    /// @param amount The amount of tokens to be spent
    /// @return Always returns true
    function approve(address spender, uint256 amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    /// @notice Transfers ETH from the caller to `recipient`.
    /// Uses ERC-7914's transferFromNative to move ETH from the caller to this contract,
    /// then forwards it to the recipient.
    ///
    /// @param recipient The address to receive the ETH
    /// @param amount The amount of ETH to transfer
    /// @return Always returns true if the transfer succeeds
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        return _transfer(msg.sender, recipient, amount);
    }

    /// @notice Transfers ETH from `from` to `recipient` using the caller's allowance.
    /// Uses ERC-7914's transferFromNative to move ETH from the source to this contract,
    /// then forwards it to the recipient.
    ///
    /// @param from The address to transfer ETH from
    /// @param recipient The address to receive the ETH
    /// @param amount The amount of ETH to transfer
    /// @return Always returns true if the transfer succeeds
    function transferFrom(address from, address recipient, uint256 amount) public override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        // Decrease allowance if not infinite approval
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        return _transfer(from, recipient, amount);
    }

    /// @notice Internal helper function to handle the common transfer logic
    /// @param from The address sending the ETH
    /// @param recipient The address receiving the ETH
    /// @param amount The amount of ETH to transfer
    /// @return Always returns true if the transfer succeeds
    function _transfer(address from, address recipient, uint256 amount) internal returns (bool) {
        // Call transferFromNative on the source to move ETH to this contract
        IERC7914(from).transferFromNative(from, address(this), amount);
        // Verify the ETH was actually received
        if (address(this).balance < amount) revert InsufficientTransferAmount();

        // Transfer ETH from this contract to the recipient
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Transfer(from, recipient, amount);
        return true;
    }

    /// @notice Fallback function to receive ETH.
    receive() external payable {}
}
