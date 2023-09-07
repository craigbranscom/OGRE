// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract ERC20Receivable {

    // mapping(address => bool) public allowedERC20Contracts;
    mapping(address => uint256) private _erc20Balances; //contract address => amount

    event ERC20Received(address from, uint256 amount, address erc20Contract);

    event ERC20Sent(address to, uint256 amount, address erc20Contract);

    constructor() {}

    function onERC20Received(address from, uint256 amount, address erc20Contract) external {
        // require(allowedERC20Contracts[erc20Contract], "contract is not allowed");
        _erc20Balances[erc20Contract] += amount;
        emit ERC20Received(from, amount, erc20Contract);
        // return this.onERC20Received.selector;
    }

    function _sendERC20(address to, address amount, address erc20Contract) internal {
        require(_erc20Balances[erc20Contract] >= amount, "insufficient balance");
        _erc20Balances[erc20Contract] -= amount;
        emit ERC20Sent(to, amount, erc20Contract);
    }
}