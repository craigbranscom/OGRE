// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../OGREFactory.sol";

/**
 * @title Stub OGREFactory Contract used in unit testing.
 */
contract StubOGREFactory is OGREFactory {
    
    constructor() {}

    function produceContract(address contractAddress, address producer) public {
        emit ContractProduced(contractAddress, address(this), producer);
    }

}