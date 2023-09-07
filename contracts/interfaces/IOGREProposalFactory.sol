// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE Proposal Factory interface definition
 */
interface IOGREProposalFactory {
    function produceOGREProposal(string memory title, address daoAddress, address owner) external returns (address);
}