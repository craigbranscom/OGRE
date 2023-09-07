// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IOGREProposalFactory.sol";
import "../abstract/OGREFactory.sol";
import "../OGREProposal.sol";

contract OGREProposalFactory is IOGREProposalFactory, OGREFactory {

    event ProposalFactoryCreated(address creator);

    constructor() {
        emit ProposalFactoryCreated(msg.sender);
    }

    function produceOGREProposal(string memory title, address daoAddress, address owner) public returns (address) {
        OGREProposal prop = new OGREProposal(title, daoAddress, owner);
        productionCount += 1;
        emit ContractProduced(address(prop), address(this), owner);
        return address(prop);
    }
}