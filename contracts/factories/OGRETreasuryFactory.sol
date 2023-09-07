// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IOGRETreasuryFactory.sol";
import "../abstract/OGREFactory.sol";
import "../OGRETreasury.sol";

contract OGRETreasuryFactory is IOGRETreasuryFactory, OGREFactory {

    event TreasuryFactoryCreated(address creator);

    constructor() {
        emit TreasuryFactoryCreated(msg.sender);
    }

    function produceOGRETreasury(address daoAddress) public returns (address) {
        OGRETreasury treasury = new OGRETreasury(daoAddress);
        productionCount += 1;
        emit ContractProduced(address(treasury), address(this), msg.sender);
        return address(treasury);
    }
}