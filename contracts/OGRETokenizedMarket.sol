// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

// import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
// import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "./abstract/ERC721Receivable.sol";
import "./interfaces/IOGRE721Factory.sol";
import "./interfaces/IOGRE721.sol";
import "./interfaces/IOGRETreasury.sol";

// import {Constants} from "./libraries/Constants.sol";
// import {Enums} from "./libraries/Enums.sol";
// import {Structs} from "./libraries/Structs.sol";

//Known Issues:
// * LISTING token can be traded while match is outstanding. Users could purchase a LISTING NFT not knowing it has already been matched to another order. Then the order 
//   executes and the newly bought LISTING token is burned and replaced with the item from the order request, which could possibly be a worthless token.
// * LISTING token could be held in a burn-unaware contract and replaced with the item from the order request upon fulfillment, causing unintended effects.
// * 

import "hardhat/console.sol";

/**
 * @title Tokenized Market Contract
 */
contract OGRETokenizedMarket {

    modifier onlyListingOwner(uint256 listingTokenId) {
        require(IERC721(listingTokenContractAddress).ownerOf(listingTokenId) == msg.sender, "sender not listing token owner");
        _;
    }

    modifier onlyFulfillmentOwner(uint256 fulfillmentTokenId) {
        require(IERC721(fulfillmentTokenContractAddress).ownerOf(fulfillmentTokenId) == msg.sender, "sender not fulfillment token owner");
        _;
    }

    enum OrderType {
        ERC20_FOR_ERC20,
        ERC20_FOR_ERC721,
        ERC721_FOR_ERC20,
        ERC721_FOR_ERC721
    }

    enum ItemType {
        ERC20,
        ERC721
    }

    struct OrderItem {
        ItemType itemType;
        address contractAddress;
        uint256 amountOrTokenId;
    }

    struct TokenizedOrder {
        OrderType orderType;
        OrderItem offered;
        OrderItem requested;
        uint256 expiration;
        uint256 fulfillmentTokenId;
    }

    struct TokenizedMatch {
        uint256 listingTokenIdA;
        uint256 listingTokenIdB;
        uint256 expiration;
        // uint256 premiumPaid;
    }

    // address public immutable depositTokenContractAddress;
    address public immutable listingTokenContractAddress;
    address public immutable fulfillmentTokenContractAddress;
    address public immutable treasuryContractAddress;

    uint256 private _lastListingId;
    uint256 private _lastFulfillmentId;

    // uint256 public matchPremiumPerSec;
    // uint256 public minMatchDurationSec;
    // uint256 public cancelMatchRewardPercent;

    mapping(uint256 => TokenizedOrder) public listings; //listingTokenId => TokenizedOrder
    mapping(uint256 => TokenizedMatch) public matches; //fulfillmentTokenId => TokenizedMatch

    event TokenizedMarketCreated(address erc721Factory, address listingTokenContract, address fulfillmentTokenContract);
    event TokenizedOrderCreated(OrderType orderType, OrderItem offer, OrderItem request, uint256 expiration, address creator, uint256 listingTokenId);
    event TokenizedOrderMatched(uint256 listingTokenIdA, uint256 listingTokenIdB, uint256 fulfillmentTokenId, uint256 expiration, address matcher);
    event TokenizedOrderFulfilled(uint256 fulfillmentTokenId, address fulfiller);
    // event PaymentSucessful(address recipient, address contractAddress, uint256 amount);

    constructor(address erc721FactoryAddress_, address treasuryContractAddress_) {
        treasuryContractAddress = treasuryContractAddress_;

        IOGRE721Factory factory = IOGRE721Factory(erc721FactoryAddress_);

        //produce listing token contract via factory
        listingTokenContractAddress = factory.produceOGRE721("OGRETokenizedMarket Listing Tokens", "LISTING", address(this));

        //produce commit token contract via factory
        // commitTokenContractAddress = factory.produceOGRE721("OGRETokenizedMarket Commit Tokens", "COMMIT", address(this));

        //produce fulfillment token contract via factory
        fulfillmentTokenContractAddress = factory.produceOGRE721("OGRETokenizedMarket Fulfillment Tokens", "FULFILL", address(this));

        emit TokenizedMarketCreated(erc721FactoryAddress_, listingTokenContractAddress, fulfillmentTokenContractAddress);
    }

    //========== Order Functions ==========

    /**
     * @notice Places a new tokenized order on the market. The offered item will be transferred to the treasury contract for storage, and a LISTING token
     * will be minted to represent ownership of the offered item. The LISTING token can be redeemed at any time to remove the associated listing from 
     * the public order book and claim the underlying offered order item.
     * @param orderType type of order defining order route (e.g. ERC20_FOR_ERC721, ERC721_FOR_ERC721)
     * @param offer order item offered by order creator
     * @param request order item requested by order creator
     * @param expiration time when order will expire and become invalid
     * @return uint256 token id for newly minted listing token
     */
    function createTokenizedOrder(OrderType orderType, OrderItem memory offer, OrderItem memory request, uint256 expiration) public returns (uint256) {
        _lastListingId += 1;
        
        //insert order
        TokenizedOrder memory listing = TokenizedOrder(
            orderType,
            offer,
            request,
            expiration,
            uint256(0)
        );
        listings[_lastListingId] = listing;

        //take custody of offer
        if (offer.itemType == ItemType.ERC20) {
            require(offer.amountOrTokenId > 0, "cannot offer zero erc20 tokens");
            uint256 preBalance = IERC20(offer.contractAddress).balanceOf(address(this));
            IERC20(offer.contractAddress).transferFrom(msg.sender, address(this), offer.amountOrTokenId);
            require(IERC20(offer.contractAddress).balanceOf(address(this)) == preBalance + offer.amountOrTokenId, "erc20 tokens not received");
        } else if (offer.itemType == ItemType.ERC721) {
            require(IERC721(offer.contractAddress).ownerOf(offer.amountOrTokenId) == msg.sender, "sender not erc721 owner");
            IERC721(offer.contractAddress).transferFrom(msg.sender, treasuryContractAddress, offer.amountOrTokenId);
            require(IERC721(offer.contractAddress).ownerOf(offer.amountOrTokenId) == treasuryContractAddress, "erc721 token not received");
        } else {
            require(false, "invalid item type in offer");
        }
        
        //mint listing token to order creator
        IOGRE721(listingTokenContractAddress).mint(msg.sender, _lastListingId);

        emit TokenizedOrderCreated(orderType, offer, request, expiration, msg.sender, _lastListingId);

        return _lastListingId;
    }

    /**
     * @notice Cancels an outstanding tokenized order. The offered item represented by the given LISTING token id will be transferred to the LISTING token holder, and
     * the LISTING token will be burned. Only callable by the LISTING token owner, and LISTING token must not be matched.
     */
    function cancelTokenizedOrder(uint256 listingTokenId) public onlyListingOwner(listingTokenId) {
        // require(listings[listingTokenId].offered.contractAddress == address(0x0), "order not found");

        // //TODO: transfer to marketplace first?

        // //burn listing token
        // IOGRE721(listingTokenContractAddress).burn(listingTokenId);

        // OrderItem memory offer = listings[listingTokenId].offered;

        // delete listings[listingTokenId];

        // //return offer back to sender
        // if (offer.itemType == ItemType.ERC20) {
        //     uint256 preBalance = IERC20(offer.contractAddress).balanceOf(address(this));
        //     require(preBalance >= offer.amountOrTokenId, "insufficient erc20 balance");
        //     IERC20(listings[listingTokenId].offered.contractAddress).transferFrom(address(this), msg.sender, listings[listingTokenId].offered.amountOrTokenId);
        //     require(IERC20(offer.contractAddress).balanceOf(address(this)) == preBalance + offer.amountOrTokenId, "erc20 tokens not received");
        // } else {
        //     require(IERC721(offer.contractAddress).ownerOf(offer.amountOrTokenId) == address(this), "erc721 token not owned by market");
        //     IERC721(offer.contractAddress).safeTransferFrom(address(this), msg.sender, offer.amountOrTokenId);
        //     require(IERC721(offer.contractAddress).ownerOf(offer.amountOrTokenId) == msg.sender, "erc721 token not received");
        // }
    }

    /**
     * @notice Attempts to establish a match between orders for `listingTokenIdA` and `listingTokenIdB` in the public order book. To qualify as
     * a valid match all the following criteria must be met:
     *    - Caller must pay a premium based on match duration if autofill is false.
     *    - Offer for listing A must match Request from listing B, and vice versa.
     *    - Both orders must not be expired.
     *    - Both orders must not already be matched.
     * If the match is found to be valid, a FULFILL token will me minted to the matcher address. A FULFILL token grants
     * the owner the sole right, but not the obligation, to fulfill the underlying match at any time before the match expiration.
     * Additionally, while the match is valid both LISTING tokens cannot be redeemed for their underlying tokens.
     * If the match expires the match creator forfeits the premium paid, and anyone that cancels the expired match will receive
     * a cut of the premium.
     * @param listingTokenIdA token id of listing a
     * @param listingTokenIdB token id of listing b
     * @param duration length of time in seconds until the match expires
     * @param autofill if true then the FULFILL token will automatically be redeemed
     * @return uint256 id of new fulfillment token representing a secured match
     */
    function matchTokenizedOrder(uint256 listingTokenIdA, uint256 listingTokenIdB, uint256 duration, bool autofill) public payable returns (uint256) {
        //validate orders
        IERC721 listingTokenContract = IERC721(listingTokenContractAddress);
        // require(listingTokenContract.ownerOf(listingTokenIdA) != address(0x0), "listing token a does not exist");
        // require(listingTokenContract.ownerOf(listingTokenIdB) != address(0x0), "listing token b does not exist");
        // require(listings[listingTokenIdA].offered.contractAddress == address(0x0), "order a not found");
        // require(listings[listingTokenIdB].offered.contractAddress == address(0x0), "order b not found");

        TokenizedOrder memory orderA = listings[listingTokenIdA];
        TokenizedOrder memory orderB = listings[listingTokenIdB];
        uint256 matchExpiration = block.timestamp + duration;

        require(orderA.fulfillmentTokenId == 0, "order a already matched");
        require(orderB.fulfillmentTokenId == 0, "order b already matched");
        require(orderA.expiration > block.timestamp, "order a has expired");
        require(orderB.expiration > block.timestamp, "order b has expired");
        require(orderA.expiration > matchExpiration, "match expiration later than order a");
        require(orderB.expiration > matchExpiration, "match expiration later than order b");

        //check order match
        if (orderA.orderType == OrderType.ERC20_FOR_ERC20) {
            require(orderB.orderType == OrderType.ERC20_FOR_ERC20, "invalid order type match 1");
        } else if (orderA.orderType == OrderType.ERC20_FOR_ERC721) {
            require(orderB.orderType == OrderType.ERC721_FOR_ERC20, "invalid order type match 2");
        } else if (orderA.orderType == OrderType.ERC721_FOR_ERC20) {
            require(orderB.orderType == OrderType.ERC20_FOR_ERC721, "invalid order type match 3");
        } else if (orderA.orderType == OrderType.ERC721_FOR_ERC721) {
            require(orderB.orderType == OrderType.ERC721_FOR_ERC721, "invalid order type match 4");
        }
        require(orderA.offered.contractAddress == orderB.requested.contractAddress, "invalid contract address match with order b");
        require(orderB.offered.contractAddress == orderA.requested.contractAddress, "invalid contract address match with order a");
        require(orderA.offered.amountOrTokenId == orderB.requested.amountOrTokenId, "invalid amount or token id match with order b");
        require(orderB.offered.amountOrTokenId == orderA.requested.amountOrTokenId, "invalid amount or token id match with order a");

        // if (autofill) {
        //     uint256 premium = matchPremiumPerSec * duration;
        //     require(msg.value == premium, "wrong premium payment");
        // } else {
        //     require(msg.value == 0, "invalid premium payment");
        // }

        //mint fulfillment token
        _lastFulfillmentId += 1;
        IOGRE721(fulfillmentTokenContractAddress).mint(msg.sender, _lastFulfillmentId);

        //mark both orders as matched
        listings[listingTokenIdA].fulfillmentTokenId = _lastFulfillmentId;
        listings[listingTokenIdB].fulfillmentTokenId = _lastFulfillmentId;

        //insert match
        TokenizedMatch memory tokenizedMatch = TokenizedMatch(
            listingTokenIdA,
            listingTokenIdB,
            matchExpiration
        );
        matches[_lastFulfillmentId] = tokenizedMatch;

        emit TokenizedOrderMatched(listingTokenIdA, listingTokenIdB, _lastFulfillmentId, matchExpiration, msg.sender);

        return _lastFulfillmentId;
    }

    /**
     * @notice Fulfills the match represented by `fulfillmentTokenId`. If the fulfillment is valid, both LISTING tokens and the
     * FULFILL token will be burned, and the order match will be executed. LISTING token holders will receive the appropriate
     * requested order items defined in the underlying order.
     * @param fulfillmentTokenId token id of match to fulfill
     */
    function fulfillTokenizedOrder(uint256 fulfillmentTokenId) public onlyFulfillmentOwner(fulfillmentTokenId) {
        TokenizedMatch memory tokenizedMatch = matches[fulfillmentTokenId];
        TokenizedOrder memory orderA = listings[tokenizedMatch.listingTokenIdA];
        TokenizedOrder memory orderB = listings[tokenizedMatch.listingTokenIdB];
        address orderAHolder = IERC721(listingTokenContractAddress).ownerOf(tokenizedMatch.listingTokenIdA);
        address orderBHolder = IERC721(listingTokenContractAddress).ownerOf(tokenizedMatch.listingTokenIdB);

        delete matches[fulfillmentTokenId];
        delete listings[tokenizedMatch.listingTokenIdA];
        delete listings[tokenizedMatch.listingTokenIdB];

        //burn fulfillment token
        IOGRE721(fulfillmentTokenContractAddress).burn(_lastFulfillmentId);

        //burn listing tokens
        IOGRE721(listingTokenContractAddress).burn(tokenizedMatch.listingTokenIdA);
        IOGRE721(listingTokenContractAddress).burn(tokenizedMatch.listingTokenIdB);

        //fulfill orders
        if (orderA.orderType == OrderType.ERC20_FOR_ERC20) {
            IERC20(orderA.requested.contractAddress).transferFrom(address(this), orderAHolder, orderA.requested.amountOrTokenId);
            IERC20(orderB.requested.contractAddress).transferFrom(address(this), orderBHolder, orderB.requested.amountOrTokenId);
        } else if (orderA.orderType == OrderType.ERC20_FOR_ERC721) {
            IERC20(orderA.requested.contractAddress).transferFrom(address(this), orderAHolder, orderA.requested.amountOrTokenId);
            IERC721(orderB.requested.contractAddress).safeTransferFrom(address(this), orderBHolder, orderB.requested.amountOrTokenId);
        } else if (orderA.orderType == OrderType.ERC721_FOR_ERC20) {
            IOGRETreasury(treasuryContractAddress).sendERC721(orderBHolder, orderA.offered.contractAddress, orderA.offered.amountOrTokenId);
            IERC20(orderB.offered.contractAddress).transfer(orderAHolder, orderB.offered.amountOrTokenId);
        } else if (orderA.orderType == OrderType.ERC721_FOR_ERC721) {
            IERC721(orderA.requested.contractAddress).safeTransferFrom(address(this), orderAHolder, orderA.requested.amountOrTokenId);
            IERC721(orderB.requested.contractAddress).safeTransferFrom(address(this), orderBHolder, orderB.requested.amountOrTokenId);
        }
    }

    //========== Internal Functions ==========

    //========== Utility Functions ==========

    // receive() external payable {}
    // fallback() external payable {}
}