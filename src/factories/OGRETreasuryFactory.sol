// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGRETreasury.sol";

contract OGRETreasuryFactory is OGREFactory {

    function produceOGRETreasury(address daoAddress) public returns (address) {
        OGRETreasury treasury = new OGRETreasury(daoAddress);
        productionCount += 1;
        emit ContractProduced(address(treasury), msg.sender);
        return address(treasury);
    }
}