// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SafeBank {
    /// @notice A custom error for insufficent balance
    error InsufficientBalance(uint256 requested, uint256 available);
    /// @notice A custom error for failed transfer transfer
    error TransferFailed();
    /// @notice A custom error for re-entrancy attackers
    error Reentrant();
    /// @notice A custom error when requestst pending is zero
    error NoPendingRequest();

    /// @notice A Deposit event thaats emitted when a user deposit
    event Deposit(address indexed from, uint256 amount);

    /// @notice A Withdraw event that's emitted when a user withdraws
    event Withdraw(address indexed to, uint256 amount);

    /// @notice A WithdrawRequest event that's emitted when a user request to withdraw
    event WithdrawRequested(address account, uint256 amount);

    /// @notice mapping to keep track of user balance
    mapping(address => uint256) private balances;

    /// @notice mapping to keep track of pending rewards
    mapping(address => uint256) private pendingWithdrawals;

    /// @notice reentrancy gaurds
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status = _NOT_ENTERED;

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
        uint256 bal = balances[msg.sender];
        if (bal < amount) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }
        balances[msg.sender] -= amount;

        (bool ok,) = payable(msg.sender).call{value: amount}("");

        if (!ok) {
            revert TransferFailed();
        }

        emit Withdraw(msg.sender, amount);
    }

    /// @notice RequestWithdraw function that allows users to request withdraw from the contract
    /// @dev implements the pull and push method
    /// @param amount The amount of token to be requested for claim;
    function requestWithdraw(uint256 amount) external {
        uint256 bal = balances[msg.sender];
        if (bal < amount) revert InsufficientBalance(amount, bal);

        balances[msg.sender] = bal - amount;
        pendingWithdrawals[msg.sender] += amount;

        emit WithdrawRequested(msg.sender, amount);
    }

    /// @notice ClaimWithdraw function that allows users to claim the amount they requested to withdraw from the contract
    /// @dev implements the pull and push method
    ///
    function claimWithdrawal() external nonReentrant {
        uint256 bal = pendingWithdrawals[msg.sender];
        if (bal == 0) revert NoPendingRequest();

        pendingWithdrawals[msg.sender] = 0;
        (bool ok,) = payable(msg.sender).call{value: bal}("");

        if (!ok) {
            revert TransferFailed();
        }

        emit Withdraw(msg.sender, bal);
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
        uint256 bal = balances[msg.sender];

        if (bal < amount) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        balances[msg.sender] -= amount;
        (bool ok,) = to.call{value: amount}("");

        if (!ok) {
            revert TransferFailed();
        }

        emit Withdraw(to, amount);
    }

    /// @notice balanceOf function that returns the user balance
    /// @dev public getter because the mapping is set to private
    /// @param account The address to check
    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    /// @notice pendingOf function that returns the user pending withdrawal balance
    /// @dev public getter because the mapping is set to private
    /// @param account The address to check
    function pendingOf(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }
}
