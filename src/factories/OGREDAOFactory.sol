// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGREDAO.sol";

contract OGREDAOFactory is OGREFactory {

    function produceOGREDAO(
        address parentDAO,
        address nft, 
        address proposalFactory, 
        uint256 proposalCost, 
        uint256 delay
    ) public returns (address) {
        OGREDAO dao = new OGREDAO(parentDAO, nft, proposalFactory, proposalCost, delay);
        productionCount += 1;
        emit ContractProduced(address(dao), msg.sender);
        return address(dao);
    }
}