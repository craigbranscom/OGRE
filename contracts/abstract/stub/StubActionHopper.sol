// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../ActionHopper.sol";

/**
 * @title Stub Action Hopper Contract used in unit testing.
 */
contract StubActionHopper is ActionHopper {
    
    constructor(uint256 delay_) ActionHopper(delay_) {}

    function loadAction(address target, uint256 value, string memory sig, bytes memory data) public {
        _loadAction(target, value, sig, data);
    }

    function cancelAction(address target, uint256 value, string memory sig, bytes memory data, uint256 ready) public {
        _cancelAction(target, value, sig, data, ready);
    }

    function executeAction(address target, uint256 value, string memory sig, bytes memory data, uint256 ready) public {
        _executeAction(target, value, sig, data, ready);
    }

    receive() external payable {}

}