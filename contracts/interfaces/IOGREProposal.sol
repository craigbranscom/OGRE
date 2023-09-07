// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Enums} from "../libraries/Enums.sol";
import {Structs} from "../libraries/Structs.sol";

/**
 * @notice OGRE proposal interface definition
 */
interface IOGREProposal {
    function proposalTitle() external view returns (string memory);
    function status() external view returns (Enums.ProposalStatus);
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function voteTotals(uint256 vote) external view returns (uint256);
    function getActionCount() external view returns (uint256);
    function getAction(uint256 index) external view returns (Structs.Action memory);

    function addAction(address target, uint256 value, string memory sig, bytes memory data) external;
    function updateStatus(uint8 newStatus) external;
    function setActionReady(uint256 index, uint256 readyTime) external;
}