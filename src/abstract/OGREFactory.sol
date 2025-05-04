// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @title OGRE Factory Abstract Contract
 */
abstract contract OGREFactory {

    uint256 public productionCount;

    /**
     * @dev Logs a successful contract production.
     * @param contractAddress address of newly produced contract
     * @param producedBy address that initiated production
     */
    event ContractProduced(address contractAddress, address producedBy);

}