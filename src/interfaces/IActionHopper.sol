// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @notice Action Hopper interface definition
 */
interface IActionHopper {

    //========== Definitions ==========
    
    struct Action {
        address target;
        uint256 value;
        string sig;
        bytes data;
        uint256 ready;
    }

    //========== Functions ==========

    // function loadAction(Action memory action) external;
    // function cancelAction(Action memory action) external;
    // function executeAction(Action memory action) external;
}