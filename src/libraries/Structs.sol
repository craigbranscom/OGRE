// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Enums} from "./Enums.sol";

library OGREDAOStructs {
    struct ConstructorParams {
        address parentDAO;
        address nftAddress;
        address proposalFactoryAddress;
        uint256 proposalCost;
        address proposalCostToken;
        uint256 quorumThreshold;
        uint256 supportThreshold;
        uint256 minVoteDuration;
        uint256 delay;
        uint256[] allowList;
        uint256[] initialMembers;
    }
}

library OGREMarketStructs {
    struct ConstructorParams {
        address daoAddress;
    }

    
}

library Structs {

    struct Action {
        address target;
        uint256 value;
        string sig;
        bytes data;
        uint256 ready;
    }

    struct Vote {
        Enums.VoteDirection direction;
        bool voted;
    }

    struct Order {
        Enums.OrderType orderType;
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
        Enums.OrderType orderType;
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

}