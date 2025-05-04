// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {OGREMarketEnums} from "../libraries/Enums.sol";

/**
 * @notice OGREMarket interface definition
 */
interface IOGREMarket {

    //========== Definitions ==========

    struct ConstructorParams {
        address daoAddress;
    }

    struct Order {
        OGREMarketEnums.OrderType orderType;
        address creator;
        address erc721Address;
        uint256 tokenId;
        address erc20Address;
        uint256 amount;
        // address recipient;
        // uint256 expiration;
        // uint256 fulfillmentId;
    }

    struct AdvancedOrder {
        OGREMarketEnums.OrderType orderType;
        address creator;
        address erc721Address;
        uint256 tokenId;
        address erc20Address;
        uint256 amount;
        uint256 listingTokenId;
        // address recipient;
        // uint256 expiration;
        // uint256 fulfillmentId;
    }

    // enum TestItemType {
    //     ERC20,
    //     ERC721,
    //     ERC1155
    // }

    // struct TestItem {
    //     TestItemType itemType;
    //     address contractAddress;
    //     uint256 amountOrTokenId;
    // }

    // struct TestAdvancedOrder {
    //     Enums.OrderType orderType;
    //     address creator;
    //     TestItem[] offered;
    //     TestItem[] requested;
    //     address recipient;
    //     uint256 expiration;
    //     uint256 listingTokenId;
    //     bool allowPartialFill;
    // }

    //========== Functions ==========

    function allowedContracts(address contractAddress) external view returns (bool);
    function createOrder(OGREMarketEnums.OrderType orderType, address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) external payable;
    function orderExists(bytes32 orderHash) external view returns (bool);
    function calcOrderHash(address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) external pure returns (bytes32);
    function calcItemHash(address erc721Address, uint256 tokenId) external pure returns (bytes32);
}