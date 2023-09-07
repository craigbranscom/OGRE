// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../node_modules/@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {Constants} from "./libraries/Constants.sol";
import {Enums} from "./libraries/Enums.sol";
import {Structs} from "./libraries/Structs.sol";

//TODO: add order expiration
//TODO: add order recipient

/**
 * @title Market Contract
 */
contract OGREMarket is AccessControl, ReentrancyGuard {

    address public immutable daoAddress;

    address public feeRecipient;
    uint256 public orderFee;
    uint256 public minOrderDuration;
    // uint256 public lastFulfillmentId;

    mapping(address => bool) public allowedContracts;
    mapping(bytes32 => bytes32) public listedItems; //itemHash => orderHash
    mapping(bytes32 => Structs.Order) public orders; //orderHash => Order

    event MarketCreated(address daoAddress);
    event OrderFeeUpdated(uint256 newOrderFee);
    event FeeRecipientUpdated(address newFeeRecipient);
    // event MinOrderDurationUpdated(uint256 newMinOrderDuration);
    event AllowlistUpdated(address contractAddress, bool allowed);
    event OrderCreated(bytes32 indexed orderHash, Enums.OrderType orderType, address creator, address erc721Address, uint256 tokenId, address erc20Address, uint256 amount);
    event OrderCancelled(bytes32 indexed orderHash);
    // event OrderContracted(bytes32 indexed orderHash, uint256 fulfillmentId);
    event OrderFulfilled(bytes32 indexed orderHash);

    constructor(address daoAddress_, address admin_, uint256 orderFee_, address feeRecipient_) {
        daoAddress = daoAddress_;
        _setupRole(Constants.MARKET_ADMIN, admin_);
        emit MarketCreated(daoAddress);
        setOrderFee(orderFee_);
        setFeeRecipient(feeRecipient_);
        // setMinOrderLength(minOrderLength_);
    }

    //========== Admin Functions ==========

    function setOrderFee(uint256 newOrderFee) public onlyRole(Constants.MARKET_ADMIN) {
        orderFee = newOrderFee;
        emit OrderFeeUpdated(newOrderFee);
    }

    function setFeeRecipient(address newFeeRecipient) public onlyRole(Constants.MARKET_ADMIN) {
        require(newFeeRecipient != address(0x0) && newFeeRecipient != address(this), "invalid address");
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    // function setMinOrderLength(uint256 newMinOrderLength) public onlyRole(Constants.MARKET_ADMIN) {
    //     require(newMinOrderLength > 0, "invalid length");
    //     minOrderLength = newMinOrderLength;
    //     emit MinOrderLengthUpdated(newMinOrderLength);
    // }

    function setContractAllowed(address contractAddress, bool allowed) public onlyRole(Constants.MARKET_ADMIN) {
        require(contractAddress != address(0x0), "invalid address");
        allowedContracts[contractAddress] = allowed;
        emit AllowlistUpdated(contractAddress, allowed);
    }

    //========== Order Functions ==========

    function createOrder(Enums.OrderType orderType, address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) public payable nonReentrant {
        require(orderType == Enums.OrderType.ASK || orderType == Enums.OrderType.BID, "invalid order type");
        require(allowedContracts[erc721Address], "erc721 contract not allowed");
        require(allowedContracts[erc20Address], "erc20 contract not allowed");
        require(amount > 0, "invalid amount");
        // require(expiration >= block.timestamp + minOrderLength, "invalid expiration");

        bytes32 orderHash = calcOrderHash(erc721Address, tokenId, erc20Address, amount);
        bytes32 itemHash = calcItemHash(erc721Address, tokenId);

        //asks indicate ownership of the erc721 item, bids indicate ownership of erc20 tokens
        IERC20 erc20Contract = IERC20(erc20Address);
        IERC721 erc721Contract = IERC721(erc721Address);
        if (orderType == Enums.OrderType.ASK) {
            require(listedItems[itemHash] == bytes32(0), "ask already exists for token id");
            require(erc721Contract.ownerOf(tokenId) == msg.sender, "not item owner");
            require(erc721Contract.getApproved(tokenId) == address(this) || erc721Contract.isApprovedForAll(msg.sender, address(this)), "not approved");
        } else {
            require(erc20Contract.balanceOf(msg.sender) >= amount, "insufficient balance");
            require(erc20Contract.allowance(msg.sender, address(this)) >= amount, "insufficient allowance");
        }

        require(msg.value == orderFee, "invalid order fee");
        (bool feeSuccess, ) = feeRecipient.call{value: orderFee}("");
        require(feeSuccess, "order fee transfer failed");

        //create new order
        if (orders[orderHash].creator == address(0x0)) {
            Structs.Order memory order = Structs.Order(
                orderType,
                msg.sender,
                erc721Address,
                tokenId,
                erc20Address,
                amount
            );
            orders[orderHash] = order;
            if (orderType == Enums.OrderType.ASK) {
                listedItems[itemHash] = orderHash;
            }
            emit OrderCreated(orderHash, orderType, msg.sender, erc721Address, tokenId, erc20Address, amount);
        } else { //attempt to fulfill existing order
            require(orders[orderHash].orderType != orderType, "order already exists");
            // require(orders[orderHash].expiration > block.timestamp, "order has expired");

            address erc721Holder;
            address erc20Holder;
            if (orderType == Enums.OrderType.ASK) {
                erc721Holder = msg.sender;
                erc20Holder = orders[orderHash].creator;
            } else {
                erc721Holder = orders[orderHash].creator;
                erc20Holder = msg.sender;
            }

            delete listedItems[itemHash];
            delete orders[orderHash];

            //requires approval from erc20 holder
            erc20Contract.transferFrom(erc20Holder, erc721Holder, amount);

            //requires approval from erc721 holder
            erc721Contract.safeTransferFrom(erc721Holder, erc20Holder, tokenId);

            emit OrderFulfilled(orderHash);
        }
    }

    function cancelOrder(bytes32 orderHash) public {
        require(orders[orderHash].creator != address(0x0), "order not found");
        require(orders[orderHash].creator == msg.sender, "not order creator");
        if (orders[orderHash].orderType == Enums.OrderType.ASK) {
            bytes32 itemHash = calcItemHash(orders[orderHash].erc721Address, orders[orderHash].tokenId);
            delete listedItems[itemHash];
        }
        delete orders[orderHash];
        emit OrderCancelled(orderHash);
    }

    //========== Utility Functions ==========

    function calcOrderHash(address erc721Address, uint256 tokenId, address erc20Address, uint256 amount) public pure returns (bytes32) {
        return keccak256(abi.encode(erc721Address, tokenId, erc20Address, amount));
    }

    function calcItemHash(address erc721Address, uint256 tokenId) public pure returns (bytes32) {
        return keccak256(abi.encode(erc721Address, tokenId));
    }

    function orderExists(bytes32 orderHash) public view returns (bool) {
        return orders[orderHash].creator != address(0x0);
    }

    /**
     * @notice Returns true if order is still valid. Non-existant orders are considered invalid.
     */
    function isValidOrder(bytes32 orderHash) public view returns (bool) {
        if (orders[orderHash].creator == address(0x0)) return false;
        if (!allowedContracts[orders[orderHash].erc721Address]) return false;
        if (!allowedContracts[orders[orderHash].erc20Address]) return false;
        
        IERC721 erc721Contract = IERC721(orders[orderHash].erc721Address);
        if (erc721Contract.ownerOf(orders[orderHash].tokenId) != orders[orderHash].creator) return false;
        if (erc721Contract.getApproved(orders[orderHash].tokenId) != address(this) || !erc721Contract.isApprovedForAll(orders[orderHash].creator, address(this))) return false;
        
        IERC20 erc20Contract = IERC20(orders[orderHash].erc20Address);
        if (erc20Contract.balanceOf(orders[orderHash].creator) < orders[orderHash].amount) return false;
        if (erc20Contract.allowance(orders[orderHash].creator, address(this)) < orders[orderHash].amount) return false;

        return true;
    }

    // receive() external payable {}
    // fallback() external payable {}
}