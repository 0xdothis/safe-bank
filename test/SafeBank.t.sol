// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SafeBank} from "../src/SafeBank.sol";
import {ReentrancyAttacker} from "../src/ReentrancyAttacker.sol";
import {RevertingRecipient} from "../src/RevertingRecipient.sol";

contract SafeBankTest is Test {
    SafeBank public safeBank;
    ReentrancyAttacker public attackerContract;
    RevertingRecipient public revertingRecipient;
    address bob = makeAddr("Bob");
    address peace = makeAddr("Peace");
    address attacker = makeAddr("Attacker");

    function setUp() public {
        safeBank = new SafeBank();
        attackerContract = new ReentrancyAttacker(address(safeBank));
        revertingRecipient = new RevertingRecipient{value: 10 ether}();
    }

    function test_user_can_deposit() external {
        deal(bob, 10 ether);

        vm.startPrank(bob);

        safeBank.deposit{value: 1 ether}();

        assertEq(address(safeBank).balance, 1 ether);

        vm.stopPrank();
    }

    function test_user_can_withdraw() external {
        deal(bob, 10 ether);

        vm.startPrank(bob);

        safeBank.deposit{value: 1 ether}();

        safeBank.withdraw(0.5 ether);

        assertEq(address(safeBank).balance, 0.5 ether);
        assertEq(address(bob).balance, 9.5 ether);

        vm.stopPrank();
    }

    function test_user_can_withdraw_to_another_user() external {
        deal(bob, 10 ether);

        vm.startPrank(bob);

        safeBank.deposit{value: 1 ether}();

        safeBank.withdrawTo(payable(peace), 0.2 ether);

        assertEq(address(safeBank).balance, 0.8 ether);
        assertEq(address(bob).balance, 9 ether);
        assertEq(address(peace).balance, 0.2 ether);

        vm.stopPrank();
    }

    function test_attacker_cant_withdraw_more() external {
        deal(bob, 10 ether);
        deal(peace, 10 ether);
        deal(attacker, 10 ether);

        vm.startPrank(bob);
        safeBank.deposit{value: 4 ether}();
        vm.stopPrank();

        vm.startPrank(peace);
        safeBank.deposit{value: 2 ether}();
        vm.stopPrank();

        vm.startPrank(attacker);
        safeBank.deposit{value: 3 ether}();
        safeBank.withdrawTo(payable(attackerContract), 2 ether);
        vm.stopPrank();

        assertEq(address(safeBank).balance, 7 ether);
        assertNotEq(address(attackerContract).balance, 4 ether);
    }

    function test_reentrancy_failure() external {
        deal(bob, 10 ether);
        deal(peace, 10 ether);
        deal(attacker, 10 ether);

        vm.startPrank(bob);
        safeBank.deposit{value: 4 ether}();
        vm.stopPrank();

        vm.startPrank(peace);
        safeBank.deposit{value: 2 ether}();
        vm.stopPrank();

        vm.startPrank(attacker);

        attackerContract.attack{value: 1 ether}();

        // vm.expectRevert();

        vm.stopPrank();

        uint256 attackBalance = safeBank.balanceOf(address(attackerContract));

        assertEq(address(attackerContract).balance, 1 ether);
        assertEq(attackBalance, 0 ether);
    }

    function test_user_can_request_withdraw() external {
        deal(bob, 10 ether);

        vm.startPrank(bob);
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(2 ether);
        vm.stopPrank();

        uint256 bobPending = safeBank.pendingOf(bob);

        assertEq(bobPending, 2 ether);
        assertEq(safeBank.balanceOf(bob), 1 ether);
    }

    function test_user_can_request_claim() external {
        deal(bob, 10 ether);

        vm.startPrank(bob);
        safeBank.deposit{value: 3 ether}();
        uint256 initialBalance = safeBank.balanceOf(bob);

        safeBank.requestWithdraw(2 ether);

        safeBank.claimWithdrawal();
        uint256 bobPending = safeBank.pendingOf(bob);
        vm.stopPrank();

        assertEq(bobPending, 0 ether);
        assertLt(initialBalance, address(bob).balance);
    }

    function test_can_disburse_batch_payments() external {
        deal(bob, 10 ether);
        deal(peace, 10 ether);
        deal(attacker, 10 ether);

        vm.startPrank(bob);
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(1 ether);
        vm.stopPrank();

        vm.startPrank(peace);
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(2 ether);
        vm.stopPrank();

        vm.startPrank(attacker);
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(3 ether);
        vm.stopPrank();

        uint256 bobPending = safeBank.pendingOf(bob);
        uint256 peacePending = safeBank.pendingOf(peace);
        uint256 attackerPending = safeBank.pendingOf(attacker);

        address[] memory recipients = new address[](3);
        recipients[0] = bob;
        recipients[1] = peace;
        recipients[2] = attacker;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = bobPending;
        amounts[1] = peacePending;
        amounts[2] = attackerPending;

        vm.expectEmit(true, true, false, true);

        emit SafeBank.Withdraw(recipients[0], amounts[0]);

        safeBank.batchDisburse(recipients, amounts, 2);

        uint256 newBobPending = safeBank.pendingOf(bob);
        uint256 newPeacePending = safeBank.pendingOf(peace);
        uint256 newAttackerPending = safeBank.pendingOf(attacker);

        assertEq(newBobPending, 0);
        assertEq(newPeacePending, 0);
        assertEq(newAttackerPending, attackerPending);
        assertEq(address(bob).balance, 8 ether);

        address[] memory recipient = new address[](1);
        recipient[0] = attacker;

        uint256[] memory amount = new uint256[](1);
        amount[0] = attackerPending;

        vm.expectEmit(true, true, false, true);

        emit SafeBank.Withdraw(recipient[0], amount[0]);

        safeBank.batchDisburse(recipient, amount, 1);

        uint256 latestAttackerPending = safeBank.pendingOf(attacker);

        assertEq(latestAttackerPending, 0);
    }

    function test_failed_to_disburse_batch_payments() external {
        bytes32 reasonHash = keccak256(bytes("failed"));
        deal(bob, 10 ether);
        deal(peace, 10 ether);

        vm.startPrank(bob);
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(1 ether);
        vm.stopPrank();

        vm.startPrank(peace);
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(2 ether);
        vm.stopPrank();

        vm.startPrank(address(revertingRecipient));
        safeBank.deposit{value: 3 ether}();

        safeBank.requestWithdraw(3 ether);
        vm.stopPrank();

        uint256 bobPending = safeBank.pendingOf(bob);
        uint256 peacePending = safeBank.pendingOf(peace);
        uint256 revertPending = safeBank.pendingOf(address(revertingRecipient));

        address[] memory recipients = new address[](3);
        recipients[0] = bob;
        recipients[1] = peace;
        recipients[2] = address(revertingRecipient);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = bobPending;
        amounts[1] = peacePending;
        amounts[2] = revertPending;

        vm.expectEmit(true, true, false, true);

        emit SafeBank.Withdraw(recipients[0], amounts[0]);

        vm.expectEmit(true, true, false, true);

        emit SafeBank.WithdrawIndexed(address(revertingRecipient), reasonHash, amounts[2]);

        safeBank.batchDisburse(recipients, amounts, 3);

        uint256 newBobPending = safeBank.pendingOf(bob);
        uint256 newPeacePending = safeBank.pendingOf(peace);
        uint256 newRevertPending = safeBank.pendingOf(address(revertingRecipient));

        assertEq(newBobPending, 0);
        assertEq(newPeacePending, 0);
        assertEq(newRevertPending, revertPending);
    }
}
