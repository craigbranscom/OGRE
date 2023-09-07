// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IOGREDAOFactory.sol";
import "../abstract/OGREFactory.sol";
import "../OGREDAO.sol";

contract OGREDAOFactory is IOGREDAOFactory, OGREFactory {

    event DAOFactoryCreated(address creator);

    constructor() {
        emit DAOFactoryCreated(msg.sender);
    }

    function produceOGREDAO(string memory name, string memory metadata, address nft, address proposalFactory, uint256 proposalCost, address admin, uint256 delay) public returns (address) {
        OGREDAO dao = new OGREDAO(name, metadata, nft, proposalFactory, proposalCost, admin, delay);
        productionCount += 1;
        emit ContractProduced(address(dao), address(this), msg.sender);
        return address(dao);
    }
}