// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGREDAO.sol";

contract OGREDAOFactory is OGREFactory {

    function produceOGREDAO(
        string memory name, 
        string memory metadata, 
        address nft, 
        address proposalFactory, 
        uint256 proposalCost, 
        address admin, 
        uint256 delay
    ) public returns (address) {
        OGREDAO dao = new OGREDAO(name, metadata, nft, proposalFactory, proposalCost, admin, delay);
        productionCount += 1;
        emit ContractProduced(address(dao), msg.sender);
        return address(dao);
    }
}