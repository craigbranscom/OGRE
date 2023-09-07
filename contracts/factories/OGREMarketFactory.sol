// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../interfaces/IOGREMarketFactory.sol";
import "../abstract/OGREFactory.sol";
import "../OGREMarket.sol";

contract OGREMarketFactory is IOGREMarketFactory, OGREFactory {

    event MarketFactoryCreated(address creator);

    constructor() {
        emit MarketFactoryCreated(msg.sender);
    }

    function produceOGREMarket(address daoAddress, address admin, uint256 orderFee, address feeRecipient) public returns (address) {
        OGREMarket mkt = new OGREMarket(daoAddress, admin, orderFee, feeRecipient);
        productionCount += 1;
        emit ContractProduced(address(mkt), address(this), msg.sender);
        return address(mkt);
    }
}