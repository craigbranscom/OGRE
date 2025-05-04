// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OGREProposalEnums} from "../libraries/Enums.sol";
import {IActionHopper} from "./IActionHopper.sol";

/**
 * @notice OGRE proposal interface definition
 */
interface IOGREProposal {

    //========== Definitions ==========

    struct ConstructorParams {
        bool revotable;
        address daoAddress;
        address owner;
        string proposalURI;
    }

    struct Vote {
        OGREProposalEnums.VoteDirection direction;
        bool voted;
    }

    //========== Functions ==========

    function proposalTitle() external view returns (string memory);
    function status() external view returns (OGREProposalEnums.ProposalStatus);
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);
    function voteTotals(uint256 vote) external view returns (uint256);
    function getActionCount() external view returns (uint256);
    function getAction(uint256 index) external view returns (IActionHopper.Action memory);

    function addAction(address target, uint256 value, string memory sig, bytes memory data) external;
    function updateStatus(uint8 newStatus) external;
    function setActionReady(uint256 index, uint256 readyTime) external;
}