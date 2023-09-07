// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IOGRE20Factory.sol";
import "../abstract/OGREFactory.sol";
import "../OGRE20.sol";

contract OGRE20Factory is IOGRE20Factory, OGREFactory {

    constructor() {}

    function produceOGRE20(string memory name, string memory symbol, address owner) public returns (address) {
        OGRE20 ogre20 = new OGRE20(name, symbol, owner);
        productionCount += 1;
        emit ContractProduced(address(ogre20), address(this), msg.sender);
        return address(ogre20);
    }
}