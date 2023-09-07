// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

// import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
// import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./abstract/ERC721Receivable.sol";
import "./interfaces/IOGRE721Factory.sol";
import "./interfaces/IOGRE721.sol";

// import {Constants} from "./libraries/Constants.sol";
// import {Enums} from "./libraries/Enums.sol";
// import {Structs} from "./libraries/Structs.sol";

/**
 * @title Advanced Market Contract
 */
contract OGREAdvancedMarket is ERC721Receivable {

    modifier onlyOwnerOf(address erc721Address, uint256 tokenId) {
        require(IERC721(erc721Address).ownerOf(tokenId) == msg.sender, "not token owner");
        _;
    }
    
    struct AdvancedOrder {
        address erc721Address;
        uint256 tokenId;
        address erc20Address;
        uint256 amount;
        uint256 expiration;
    }

    address public immutable listingTokenContractAddress;
    address public immutable fulfillmentTokenContractAddress;

    uint256 private _lastListingId;

    mapping(uint256 => AdvancedOrder) public orders; //listingTokenId => AdvancedOrder

    event AdvancedMarketCreated();

    constructor(address erc721FactoryAddress_) {
        IOGRE721Factory factory = IOGRE721Factory(erc721FactoryAddress_);

        //produce listing token contract via factory
        listingTokenContractAddress = factory.produceOGRE721("OGREAdvancedMarket Listing Tokens", "LISTING", address(this));

        //produce fulfillment token contract via factory
        fulfillmentTokenContractAddress = factory.produceOGRE721("OGREAdvancedMarket Fulfillment Tokens", "FULFILL", address(this));
    }

    //========== Order Functions ==========

    function createAdvancedOrder(address erc721Address, uint256 tokenId, address erc20Address, uint256 amount, uint256 expiration) public payable onlyOwnerOf(erc721Address, tokenId) returns (uint256) {
        //mint listing token
        _lastListingId += 1;
        IOGRE721(listingTokenContractAddress).mint(msg.sender, _lastListingId);
        
        //insert order
        AdvancedOrder memory listing = AdvancedOrder(
            erc721Address,
            tokenId,
            erc20Address,
            amount,
            expiration
        );
        orders[_lastListingId] = listing;

        //take custody of listed token
        IERC721(erc721Address).safeTransferFrom(msg.sender, address(this), tokenId);

        return _lastListingId;
    }

    function cancelAdvancedOrder(uint256 listingTokenId) public onlyOwnerOf(listingTokenContractAddress, listingTokenId) {
        //burn listing token
        IOGRE721(listingTokenContractAddress).burn(_lastListingId);

        //return listed item back to sender
        IERC721(orders[listingTokenId].erc721Address).safeTransferFrom(address(this), msg.sender, orders[listingTokenId].tokenId);

        delete orders[listingTokenId];
    }

    function commitAdvancedOrder(uint256 listingTokenId) public onlyOwnerOf(listingTokenContractAddress, listingTokenId) returns (uint256) {
        //take custody of listing token
        IERC721(listingTokenContractAddress).safeTransferFrom(msg.sender, address(this), listingTokenId);

        //mint fulfillment token
        IOGRE721(listingTokenContractAddress).mint(msg.sender, listingTokenId);
    }

    // function fulfillAdvancedOrder(uint256 fulfillmentTokenId) public onlyOwnerOf(fulfillmentTokenContractAddress, fulfillmentTokenId) {
    //     //burn fulfillment token
    //     IOGRE721(listingTokenContractAddress).burn(_lastListingId);

    //     //take custody of erc20 tokens
    //     IERC20(orders[fulfillmentTokenId].erc20Address).transferFrom(msg.sender, address(this), orders[fulfillmentTokenId].amount);

    //     //send erc721 token to fulfiller
    //     IERC721(orders[fulfillmentTokenId].erc721Address).safeTransferFrom(address(this), msg.sender, orders[fulfillmentTokenId].tokenId);
    // }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public override returns (bytes4) {
        require(IERC721(from).ownerOf(tokenId) == address(this), "item not received");
        if (data.length > 0) {
            //decode action
            
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    //========== Internal Functions ==========



    //========== Utility Functions ==========



    // receive() external payable {}
    // fallback() external payable {}
}