// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE DAO Factory interface definition
 */
interface IOGREDAOFactory {
    function produceOGREDAO(string memory name, string memory metadata, address nft, address prpoopsalFactory, uint256 proposalCost, address owner, uint256 delay) external returns (address);
}