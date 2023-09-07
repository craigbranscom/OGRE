// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IOGRE721Factory.sol";
import "../abstract/OGREFactory.sol";
import "../OGRE721.sol";

contract OGRE721Factory is IOGRE721Factory, OGREFactory {

    constructor() {}

    function produceOGRE721(string memory name, string memory symbol, address owner) public returns (address) {
        OGRE721 nft = new OGRE721(name, symbol, owner);
        productionCount += 1;
        emit ContractProduced(address(nft), address(this), msg.sender);
        return address(nft);
    }
}