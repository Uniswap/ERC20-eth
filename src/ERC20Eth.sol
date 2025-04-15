// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC7914} from "./interfaces/IERC7914.sol";

contract ERC20ETH is IERC20 {
    error BalanceOfNotSupported();
    error InsufficientTransferAmount();
    error TransferFailed();

    uint256 public constant override totalSupply = 0;
    uint8 public constant override decimals = 18;
    string public override name;
    string public override symbol;

    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        name = "ERC20 ETH";
        symbol = "ETH";
    }

    function balanceOf(address) public pure override returns (uint256) {
        // capturing account balances via the token is not supported
        // to prevent double-entrypoint balance check bugs
        revert BalanceOfNotSupported();
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        IERC7914(msg.sender).transferFromNative(msg.sender, address(this), amount);

        if (address(this).balance < amount) revert InsufficientTransferAmount();

        // transfer ETH from the sender to the recipient
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address from, address recipient, uint256 amount) public override returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        IERC7914(from).transferFromNative(from, address(this), amount);

        if (address(this).balance < amount) revert InsufficientTransferAmount();

        // transfer ETH from the sender to the recipient
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Transfer(from, recipient, amount);
        return true;
    }

    receive() external payable {}
}
