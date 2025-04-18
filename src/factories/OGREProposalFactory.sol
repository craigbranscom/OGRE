// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGREProposal.sol";

contract OGREProposalFactory is OGREFactory {

    function produceOGREProposal(string memory title, address daoAddress, address owner) public returns (address) {
        OGREProposal prop = new OGREProposal(title, daoAddress, owner);
        productionCount += 1;
        emit ContractProduced(address(prop), owner);
        return address(prop);
    }
}