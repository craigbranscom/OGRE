// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE Treasury Factory interface definition
 */
interface IOGRETreasuryFactory {
    function produceOGRETreasury(address daoAddress) external returns (address);
}