// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {SafeBank} from "../src/SafeBank.sol";
import {ReentrancyAttacker} from "../src/ReentrancyAttacker.sol";

contract SafeBankTest is Test {
    SafeBank public safeBank;
    ReentrancyAttacker public attackerContract;
    address bob = makeAddr("Bob");
    address peace = makeAddr("Peace");
    address attacker = makeAddr("Attacker");

    function setUp() public {
        safeBank = new SafeBank();
        attackerContract = new ReentrancyAttacker(address(safeBank));
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
}
