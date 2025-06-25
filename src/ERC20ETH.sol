// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {ERC20} from "solady/tokens/ERC20.sol";
import {IERC7914} from "./interfaces/IERC7914.sol";

/// @title ERC20ETH
/// @notice An ERC20 wrapper for native ETH that leverages ERC-7914 for smart wallet compatibility.
///
/// This contract allows native ETH to be used with ERC20 interfaces by implementing the ERC20 standard
/// while using ERC-7914's transferFromNative hook to move ETH from smart wallets.
///
/// Key features:
/// - Uses ERC-7914 for native ETH transfers from smart wallets
/// - Does not track balances internally (relies on native ETH balances)
///
/// Integration notes:
/// - Do not send ETH directly to this contract. Only use the transfer() or transferFrom() functions.
/// - Check ETH balances directly instead of relying upon this contract's balanceOf, totalSupply, or Transfer events.
/// - Ensure the caller of this contract uses appropriate reentrancy guards.
/// @custom:security-contact security@uniswap.org
contract ERC20ETH is ERC20 {
    /// @notice Thrown when balanceOf is called, as this contract doesn't track balances internally
    /// to prevent double-entrypoint balance check bugs.
    error BalanceOfNotSupported();

    /// @notice Thrown when the contract doesn't have enough ETH to complete a transfer.
    error InsufficientTransferAmount();

    /// @notice Thrown when an ETH transfer fails.
    error TransferFailed();

    /// @dev Returns the name of the token.
    /// @return The name of the token as a string
    function name() public pure override returns (string memory) {
        return "ERC20 ETH";
    }

    /// @dev Returns the symbol of the token.
    /// @return The symbol of the token as a string
    function symbol() public pure override returns (string memory) {
        return "ETH";
    }

    /// @dev Not applicable to this contract.
    /// @return Always returns 0 as this contract doesn't track total supply
    function totalSupply() public pure override returns (uint256) {
        return 0;
    }

    /// @notice This function is intentionally disabled to prevent double-entrypoint balance check bugs.
    /// Users should check ETH balances directly instead of through this contract.
    /// @return Never returns, always reverts
    function balanceOf(address) public pure override returns (uint256) {
        // capturing account balances via the token is not supported
        // to prevent double-entrypoint balance check bugs
        revert BalanceOfNotSupported();
    }

    /// @notice Transfers ETH from the caller to `recipient`.
    /// Uses ERC-7914's transferFromNative to move ETH from the caller to this contract,
    /// then forwards it to the recipient.
    ///
    /// @param recipient The address to receive the ETH
    /// @param amount The amount of ETH to transfer
    /// @return Always returns true if the transfer succeeds
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
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
        _spendAllowance(from, msg.sender, amount);

        _transfer(from, recipient, amount);
        return true;
    }

    /// @notice Internal helper function to handle the common transfer logic
    /// @param from The address sending the ETH
    /// @param recipient The address receiving the ETH
    /// @param amount The amount of ETH to transfer
    function _transfer(address from, address recipient, uint256 amount) internal override {
        // Call transferFromNative on the source to move ETH to this contract
        IERC7914(from).transferFromNative(from, address(this), amount);
        // Verify the ETH was actually received
        if (address(this).balance < amount) revert InsufficientTransferAmount();

        // Transfer ETH from this contract to the recipient
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Transfer(from, recipient, amount);
    }

    /// @notice Sets Permit2 contract's allowance at infinity.
    function _givePermit2InfiniteAllowance() internal view virtual override returns (bool) {
        return true;
    }

    /// @notice Fallback function to receive ETH.
    receive() external payable {}
}
