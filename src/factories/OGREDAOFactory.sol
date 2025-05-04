// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGREDAO.sol";
import {IOGREDAO} from "../interfaces/IOGREDAO.sol";

contract OGREDAOFactory is OGREFactory {

    /**
     * @notice Produces a new OGREDAO
     * @param parentDAO address of parent DAO
     * @param nft address of nft contract
     * @param proposalFactory address of proposal factory
     * @param proposalCost cost of proposal
     * @param proposalCostToken address of proposal cost token
     * @param quorumThreshold quorum threshold
     * @param supportThreshold support threshold
     * @param minVoteDuration minimum vote duration
     * @param delay delay
     * @param allowList allow list
     * @param initialMembers initial members
     * @return address of new OGREDAO
     */
    function produceOGREDAO(
        address parentDAO,
        address nft, 
        address proposalFactory, 
        uint256 proposalCost, 
        address proposalCostToken,
        uint256 quorumThreshold,
        uint256 supportThreshold,
        uint256 minVoteDuration,
        uint256 delay,
        uint256[] memory allowList,
        uint256[] memory initialMembers
    ) public returns (address) {
        IOGREDAO.ConstructorParams memory params = IOGREDAO.ConstructorParams({
            parentDAO: parentDAO,
            nftAddress: nft,
            proposalFactoryAddress: proposalFactory,
            proposalCost: proposalCost,
            proposalCostToken: proposalCostToken,
            quorumThreshold: quorumThreshold,
            supportThreshold: supportThreshold,
            minVoteDuration: minVoteDuration,
            delay: delay,
            allowList: allowList,
            initialMembers: initialMembers
        });
        OGREDAO dao = new OGREDAO(params);
        productionCount += 1;
        emit ContractProduced(address(dao), msg.sender);
        return address(dao);
    }
}