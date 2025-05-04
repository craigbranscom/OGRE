// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../abstract/OGREFactory.sol";
import "../OGREMarket.sol";

contract OGREMarketFactory is OGREFactory {

    function produceOGREMarket(
        address daoAddress, 
        address admin, 
        uint256 orderFee, 
        address feeRecipient
    ) public returns (address) {
        OGREMarket mkt = new OGREMarket(daoAddress, admin, orderFee, feeRecipient);
        productionCount += 1;
        emit ContractProduced(address(mkt), msg.sender);
        return address(mkt);
    }
}