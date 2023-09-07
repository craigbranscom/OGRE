// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title OGRE Factory Abstract Contract
 */
abstract contract OGREFactory {

    uint256 public productionCount;
    // mapping(address => uint256) public contractsProduced;
    // mapping(uint256 => address) public contractsProducedById;

    /**
     * @dev logs a successful contract production from factory
     * @param contractAddress address of newly produced contract
     * @param factoryAddress address of factory that produced contract
     * @param producer address that initiated production
     */
    event ContractProduced(address contractAddress, address factoryAddress, address producer);

    constructor() {}

}