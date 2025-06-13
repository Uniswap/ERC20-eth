// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20ETH} from "../src/ERC20Eth.sol";
import {IERC7914} from "../src/interfaces/IERC7914.sol";

// Mock contract implementing IERC7914 for testing
contract MockERC7914 is IERC7914 {
    bool forceFailure = false;

    error AllowanceExceeded();

    mapping(address spender => uint256 allowance) public nativeAllowance;

    function setForceFailure(bool _forceFailure) external {
        forceFailure = _forceFailure;
    }

    function transferFromNative(address, address recipient, uint256 amount) external returns (bool) {
        if (forceFailure) {
            revert AllowanceExceeded();
        }

        // Send ETH to recipient
        (bool success,) = recipient.call{value: amount}("");
        return success;
    }

    function approveNative(address spender, uint256 amount) external returns (bool) {
        nativeAllowance[spender] = amount;
        return true;
    }

    // Allow the contract to receive ETH (for testTransferToSelf)
    receive() external payable {}
}

contract ERC20ETHTest is Test {
    ERC20ETH public token;
    MockERC7914 public mockERC7914;
    address public alice;
    address public bob;
    address public charlie;
    address public permit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // Declare the ERC20 Transfer event for testing
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        token = new ERC20ETH();
        mockERC7914 = new MockERC7914();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
    }

    // Basic ERC20 property tests
    function testNameAndSymbol() public view {
        assertEq(token.name(), "ERC20 ETH", "Incorrect token name");
        assertEq(token.symbol(), "ETH", "Incorrect token symbol");
    }

    function testTotalSupply() public view {
        assertEq(token.totalSupply(), 0, "Total supply should be 0");
    }

    function testBalanceOfReverts() public {
        vm.expectRevert(ERC20ETH.BalanceOfNotSupported.selector);
        token.balanceOf(alice);
    }

    // Transfer tests
    function testTransferSuccess() public {
        // Give mockERC7914 some ETH
        vm.deal(address(mockERC7914), 10 ether);

        // Use prank to simulate msg.sender as mockERC7914
        vm.startPrank(address(mockERC7914));

        // Call transfer to bob
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(mockERC7914), bob, 1 ether);
        bool result = token.transfer(bob, 1 ether);
        assertTrue(result, "Transfer should succeed");
        vm.stopPrank();

        // Check bob received ETH
        assertEq(bob.balance, 1 ether, "Bob should receive 1 ether");
        vm.snapshotGasLastCall("transfer_success");
    }

    function testTransferFromSuccess() public {
        // Give mockERC7914 some ETH
        vm.deal(address(mockERC7914), 10 ether);

        // Approve the test contract to spend on behalf of mockERC7914
        vm.prank(address(mockERC7914));
        token.approve(address(this), 2 ether);

        // Call transferFrom as the test contract, from mockERC7914 to bob
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(mockERC7914), bob, 2 ether);
        bool result = token.transferFrom(address(mockERC7914), bob, 2 ether);
        assertTrue(result, "TransferFrom should succeed");

        // Check bob received ETH
        assertEq(bob.balance, 2 ether, "Bob should receive 2 ether");
        vm.snapshotGasLastCall("transfer_from_success");
    }

    function testTransferFromCannotExceedAllowance() public {
        // Give mockERC7914 some ETH
        vm.deal(address(mockERC7914), 10 ether);

        // Approve the test contract to spend on behalf of mockERC7914
        vm.prank(address(mockERC7914));
        token.approve(address(this), 1 ether);

        // Call transferFrom as the test contract, from mockERC7914 to bob
        vm.expectRevert(bytes4(keccak256("InsufficientAllowance()")));
        token.transferFrom(address(mockERC7914), bob, 2 ether);
        vm.snapshotGasLastCall("transfer_from_cannot_exceed_allowance");
    }

    function testTransferFrom7914TransferFailure() public {
        // Give mockERC7914 some ETH
        vm.deal(address(mockERC7914), 10 ether);

        // Approve the test contract to spend on behalf of mockERC7914
        vm.prank(address(mockERC7914));
        token.approve(address(this), 2 ether);

        // Set the mockERC7914 to force failure
        mockERC7914.setForceFailure(true);

        // Call transferFrom as the test contract, from mockERC7914 to bob
        vm.expectRevert(MockERC7914.AllowanceExceeded.selector);
        bool result = token.transferFrom(address(mockERC7914), bob, 2 ether);
        assertFalse(result, "TransferFrom should fail");

        // Check bob received no ETH
        assertEq(bob.balance, 0 ether, "Bob should receive no ETH");
        vm.snapshotGasLastCall("transfer_from_7914_transfer_failure");
    }

    function testTransferFromWithoutApproval() public {
        // Give mockERC7914 some ETH
        vm.deal(address(mockERC7914), 10 ether);

        // Call transferFrom as the test contract (no approval), from
        // mockERC7914 to bob
        vm.expectRevert(bytes4(keccak256("InsufficientAllowance()")));
        token.transferFrom(address(mockERC7914), bob, 2 ether);
        vm.snapshotGasLastCall("transfer_from_without_approval");
    }

    function testPermit2InfiniteAllowance() public {
        // Give mockERC7914 some ETH
        vm.deal(address(mockERC7914), 10 ether);

        vm.prank(permit2);
        token.transferFrom(address(mockERC7914), bob, 1 ether);
        assertEq(bob.balance, 1 ether, "Bob should receive 1 ether");
        vm.snapshotGasLastCall("permit2_infinite_allowance");
    }

    function testTransferInsufficientAmount() public {
        // Use prank to simulate msg.sender as mockERC7914
        vm.startPrank(address(mockERC7914));
        vm.expectRevert(ERC20ETH.InsufficientTransferAmount.selector);
        token.transfer(bob, 1 ether);
        vm.stopPrank();
        vm.snapshotGasLastCall("transfer_insufficient_amount");
    }

    function testTransferToRejector() public {
        // Use a contract that will reject ETH
        address rejector = address(new Rejector());
        vm.deal(address(mockERC7914), 1 ether);

        vm.startPrank(address(mockERC7914));
        vm.expectRevert(ERC20ETH.TransferFailed.selector);
        token.transfer(rejector, 1 ether);
        vm.stopPrank();
        vm.snapshotGasLastCall("transfer_to_rejector");
    }

    // Edge cases
    function testZeroAmountTransfer() public {
        vm.deal(address(mockERC7914), 1 ether);
        vm.startPrank(address(mockERC7914));

        // Zero amount transfer should succeed
        bool result = token.transfer(bob, 0);
        assertTrue(result, "Zero amount transfer should succeed");
        assertEq(bob.balance, 0, "Bob should not receive any ETH");
        vm.stopPrank();
    }

    function testTransferToSelf() public {
        vm.deal(address(mockERC7914), 1 ether);
        vm.startPrank(address(mockERC7914));

        // Transfer to self should succeed
        bool result = token.transfer(address(mockERC7914), 1 ether);
        assertTrue(result, "Transfer to self should succeed");
        assertEq(address(mockERC7914).balance, 1 ether, "Balance should remain unchanged");
        vm.stopPrank();
    }

    function testMultipleTransfers() public {
        vm.deal(address(mockERC7914), 3 ether);
        vm.startPrank(address(mockERC7914));

        // Perform multiple transfers
        assertTrue(token.transfer(bob, 1 ether), "First transfer should succeed");
        assertTrue(token.transfer(charlie, 1 ether), "Second transfer should succeed");
        assertTrue(token.transfer(alice, 1 ether), "Third transfer should succeed");

        assertEq(bob.balance, 1 ether, "Bob should receive 1 ether");
        assertEq(charlie.balance, 1 ether, "Charlie should receive 1 ether");
        assertEq(alice.balance, 1 ether, "Alice should receive 1 ether");
        vm.stopPrank();
    }

    // Security tests
    function testReentrancyProtection() public {
        // Create a malicious contract that tries to reenter during transfer
        MaliciousContract malicious = new MaliciousContract(address(token), address(mockERC7914));
        vm.deal(address(mockERC7914), 2 ether);

        vm.startPrank(address(mockERC7914));
        // The transfer should fail since the malicious contract will try to
        // transfer more tokens to itself through reentrancy
        vm.expectRevert(ERC20ETH.TransferFailed.selector);
        bool result = token.transfer(address(malicious), 1 ether);
        assertFalse(result, "Transfer should fail");
        vm.stopPrank();
    }

    function testETHBalanceManipulation() public {
        vm.deal(address(mockERC7914), 1 ether);
        vm.startPrank(address(mockERC7914));

        // Try to transfer more than the contract has
        vm.expectRevert(ERC20ETH.InsufficientTransferAmount.selector);
        token.transfer(bob, 2 ether);
        vm.stopPrank();
    }

    function testRevokeAllowance() public {
        vm.deal(address(mockERC7914), 1 ether);

        // Approve bob to spend 1 ether
        vm.prank(address(mockERC7914));
        token.approve(bob, 1 ether);

        // Revoke allowance by approving zero
        vm.prank(address(mockERC7914));
        token.approve(bob, 0);

        // Try to transfer after allowance revoked (should fail)
        vm.prank(bob);
        vm.expectRevert(bytes4(keccak256("InsufficientAllowance()")));
        token.transferFrom(address(mockERC7914), charlie, 1 ether);
    }
}

// Helper contract to reject ETH transfers
contract Rejector {
    receive() external payable {
        revert("Rejecting ETH");
    }
}

// Malicious contract that tries to reenter during transfer
contract MaliciousContract {
    ERC20ETH public token;
    address public sender;

    constructor(address _token, address _sender) {
        token = ERC20ETH(payable(_token));
        sender = _sender;
    }

    receive() external payable {
        // Try to reenter and transfer more tokens to self
        token.transferFrom(sender, address(this), 1 ether);
    }
}
