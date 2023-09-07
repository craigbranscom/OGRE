// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "./abstract/ERC721Receivable.sol";
import "./interfaces/IOGREMarket.sol";

import {Constants} from "./libraries/Constants.sol";
import {Enums} from "./libraries/Enums.sol";
import {Structs} from "./libraries/Structs.sol";

//TODO: adjust premium by option duration

contract OGREOptions is AccessControl, ERC721, ReentrancyGuard {

    address public immutable daoAddress;

    uint256 public optionPremium; //in wei

    uint256 private _lastFulfillmentId;

    struct OrderOption {
        uint256 fulfillmentId;
        uint256 expiration;
    }

    mapping(bytes32 => OrderOption) public options; //orderHash => orderOption

    event OptionCreated(bytes32 orderHash, uint256 fulfillmentId, address creator);
    event OptionPurchased();

    constructor(address daoAddress_, address admin_) ERC721("OGREOptions Fulfillment Tokens", "FULFILL") {
        daoAddress = daoAddress_;
        _setupRole(Constants.OPTIONS_ADMIN, admin_);
    }

    //========== Admin Functions ==========



    //========== Options ==========

    function createOption(bytes32 orderHash, uint256 expiration) public payable nonReentrant {

        //TODO: charge premium

        //mint fulfillment token
        _lastFulfillmentId += 1;
        _safeMint(msg.sender, _lastFulfillmentId);

        OrderOption memory option = OrderOption(
            _lastFulfillmentId,
            expiration
        );
        options[orderHash] = option;

        emit OptionCreated(orderHash, _lastFulfillmentId, msg.sender);
    }

    function exerciseOption(bytes32 orderHash, uint256 fulfillmentId) public payable nonReentrant {
        require(options[orderHash].fulfillmentId != 0, "option not found");
        require(fulfillmentId != 0, "invalid fulfillment id");
    }

    //========== Utility Functions ==========

    function calcOrderHash(address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) public pure returns (bytes32) {
        return keccak256(abi.encode(erc721Address, tokenId, erc20Address, amount));
    }

    function calcItemHash(address erc721Address, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encode(erc721Address, tokenId));
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl, ERC721) returns (bool) {
        return
            interfaceId == type(IAccessControl).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    // receive() external payable {}
    // fallback() external payable {}
}