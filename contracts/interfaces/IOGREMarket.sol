// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {Enums} from "../libraries/Enums.sol";

/**
 * @notice OGREMarket interface definition
 */
interface IOGREMarket {
    function allowedContracts(address contractAddress) external view returns (bool);
    function createOrder(Enums.OrderType orderType, address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) external payable;
    function orderExists(bytes32 orderHash) external view returns (bool);
    function calcOrderHash(address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) external pure returns (bytes32);
    function calcItemHash(address erc721Address, uint256 tokenId) external pure returns (bytes32);
}