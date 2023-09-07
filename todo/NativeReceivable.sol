// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract NativeReceivable {

    // mapping(address => bool) public allowedAddresses;

    event NativeReceived(address from, uint256 amount);

    event NativeSent(address to, uint256 amount);

    constructor() {}

    function onNativeReceived() external payable {
        require(msg.value > 0, "must deposit non-zero amount");
        emit NativeReceived(msg.sender, msg.value);
    }

    function _sendNative(address to, uint256 amount) internal {
        require(address(this).balance >= amount, "insufficient funds");
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "failed to send native");
    }
    
}