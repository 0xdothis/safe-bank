// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SafeBank} from "../src/SafeBank.sol";

contract CounterScript is Script {
    SafeBank public safeBank;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        safeBank = new SafeBank();

        vm.stopBroadcast();
    }
}
