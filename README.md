<<<<<<< HEAD

# ERC20 ETH

A Solidity implementation of an ERC20 wrapper for native ETH that leverages [ERC-7914](https://github.com/ethereum/ERCs/pull/987) for smart wallet compatibility.

## Overview

This project implements an ERC20 token contract that wraps native ETH, allowing it to be used with ERC20-compatible interfaces and applications. The key innovation is the use of ERC-7914's `transferFromNative` hook to enable seamless ETH transfers from smart contract wallets.

### Key Features

- **ERC20 Interface for ETH**: Implements the standard ERC20 interface for native ETH
- **Smart Wallet Compatibility**: Uses ERC-7914 to enable ETH transfers from smart contract wallets
- **No Balance Tracking**: Relies on native ETH balances rather than internal accounting
- **Standard Allowance Mechanism**: Maintains the ERC20 allowance system for `transferFrom` operations

## How It Works

The ERC20ETH contract works as follows:

1. When a user calls `transfer` or `transferFrom`, the contract calls `transferFromNative` on the sender's address
2. The sender (which must implement ERC-7914) transfers ETH to the ERC20ETH contract
3. The ERC20ETH contract then forwards the ETH to the intended recipient
4. Standard ERC20 events are emitted to maintain compatibility with existing tools and interfaces

## Security Considerations

- The contract intentionally reverts on `balanceOf` calls to prevent double-entrypoint balance check bugs
- The contract verifies that ETH was actually received before forwarding it to the recipient
- Standard allowance checks are performed for `transferFrom` operations

## Integration Guide

To integrate with this contract, smart wallets must implement the ERC-7914 interface:

```solidity
interface IERC7914 {
    function transferFromNative(address from, address recipient, uint256 amount) external returns (bool);
    function approveNative(address spender, uint256 amount) external returns (bool);
}

```
