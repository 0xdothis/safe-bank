// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SafeBank {
    /// @notice A custom error for insufficent balance
    error InsufficientBalance(uint256 requested, uint256 available);
    /// @notice A custom error for failed transfer transfer
    error TransactionFailed();
    /// @notice A custom error for re-entrancy attackers
    error Reentrant();

    /// @notice A Deposit event thaats emitted when a user deposit
    event Deposit(address indexed from, uint256 amount);

    /// @notice A Withdraw event that's emitted when a user withdraws
    event Withdraw(address indexed to, uint256 amount);

    /// @notice mapping to keep track of user balance
    mapping(address => uint256) private balances;

    /// @notice reentrancy gaurds
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

    /// @notice a private variable to track when a function is active
    bool private locked;

    /// @notice Deposit function that allows user to deposit ether
    /// @dev payable function allows countract to handle ether
    function deposit() external payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    /// @notice Withdraw function that allows users to withdraw from the contract
    /// @dev Uses re-entrancy gaurd to protect against attackers
    /// @param amount The amount of token to be withdrawn
    function withdraw(uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }
        balances[msg.sender] -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");

        if (!ok) {
            revert TransactionFailed();
        }

        emit Withdraw(msg.sender, amount);
    }

    /// @notice A re-entrant modifier
    /// @dev make sure the contract is locked during a single transaction
    modifier nonReentrant() {
        if (_status == _ENTERED) revert Reentrant();
        _status = _ENTERED;

        _;

        _status = _NOT_ENTERED;
    }

    /// @notice WithdrawTo function that allows users to withdraw from the balance to another account
    /// @dev Uses re-entrancy gaurd to protect against attackers
    /// @param to The address of the receiver
    /// @param amount The amount of token to be withdrawn

    function withdrawTo(address payable to, uint256 amount) external nonReentrant {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        balances[msg.sender] -= amount;
        (bool ok,) = to.call{value: amount}("");

        if (!ok) {
            revert TransactionFailed();
        }

        emit Withdraw(to, amount);
    }

    function balanceOf(address acount) external view returns (uint256) {
        return balances[acount];
    }
}
