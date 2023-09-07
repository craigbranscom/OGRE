// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGREMarketFactory interface definition
 */
interface IOGREMarketFactory {
    function produceOGREMarket(address daoAddress, address admin, uint256 orderFee, address feeRecipient) external returns (address);
}