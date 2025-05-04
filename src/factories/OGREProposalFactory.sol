// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGREProposal.sol";
import {IOGREProposal} from "../interfaces/IOGREProposal.sol";

contract OGREProposalFactory is OGREFactory {

    function produceOGREProposal(
        string memory proposalURI, 
        address daoAddress, 
        address owner
    ) public returns (address) {
        IOGREProposal.ConstructorParams memory _params_ = IOGREProposal.ConstructorParams({
            revotable: false,
            daoAddress: daoAddress,
            owner: owner,
            proposalURI: proposalURI
        });
        OGREProposal prop = new OGREProposal(_params_);
        productionCount += 1;
        emit ContractProduced(address(prop), owner);
        return address(prop);
    }
}