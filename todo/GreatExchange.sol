// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

//TODO: make order items an array?
//TODO: remove contract allowlist? change to banlist? would have to approve every contract address manually...
//TODO: move item type into allowlist and remove from Order struct?
//TODO: add creator and/or recipient to order hash?
//TODO: implement order janitor role?

/**
 * @title Great Exchange Contract
 */
contract GreatExchange is AccessControl {

    bytes32 public constant EXCHANGE_ADMIN = keccak256("EXCHANGE_ADMIN");

    enum ContractType {
        ERC20,
        ERC721
    }

    struct OrderItem {
        ContractType contractType;
        address contractAddress;
        uint256 amountOrTokenId;
    }

    struct Order {
        OrderItem offered;
        OrderItem requested;
        address creator;
        address recipient;
        uint256 expiration;
        // uint256 bundleId;
    }

    // struct OrderBundle {
    //     uint32 bundleSize;
    //     bool allowPartialFill;
    //     bytes32[] orderHashes;
    // }

    // struct AllowlistEntry {
    //     bool allowed;
    //     ContractType contractType;
    // }

    address public feeRecipient;
    uint256 public orderFee;
    uint256 public minOrderDuration;

    mapping(address => bool) public allowedContracts;
    mapping(bytes32 => Order) public orderbook; //orderHash => Order
    // mapping(uint256 => OrderBundle) public bundles; //bundleId => Bundle

    event OrderFeeUpdated(uint256 newOrderFee);
    event FeeRecipientUpdated(address newFeeRecipient);
    event MinOrderDurationUpdated(uint256 newMinOrderDuration);
    event AllowlistUpdated(address contractAddress, bool allowed);
    event OrderCreated(bytes32 indexed orderHash, OrderItem offered, OrderItem requested, address indexed creator, address indexed recipient, uint256 expiration);
    event OrderCancelled(bytes32 indexed orderHash, address cancelledBy);
    event OrderFulfilled(bytes32 indexed orderHash, address fulfilledBy);

    constructor(address admin_, uint256 orderFee_, address feeRecipient_, uint256 minOrderDuration_) {
        _setupRole(EXCHANGE_ADMIN, admin_);
        setOrderFee(orderFee_);
        setFeeRecipient(feeRecipient_);
        setMinOrderDuration(minOrderDuration_);
    }

    //========== Admin Functions ==========

    function setOrderFee(uint256 newOrderFee) public onlyRole(EXCHANGE_ADMIN) {
        orderFee = newOrderFee;
        emit OrderFeeUpdated(newOrderFee);
    }

    function setFeeRecipient(address newFeeRecipient) public onlyRole(EXCHANGE_ADMIN) {
        require(newFeeRecipient != address(0x0) && newFeeRecipient != address(this), "invalid address");
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    function setMinOrderDuration(uint256 newMinOrderDuration) public onlyRole(EXCHANGE_ADMIN) {
        require(newMinOrderDuration > 0, "invalid duration");
        minOrderDuration = newMinOrderDuration;
        emit MinOrderDurationUpdated(newMinOrderDuration);
    }

    function setContractAllowed(address contractAddress, bool allowed) public onlyRole(EXCHANGE_ADMIN) {
        require(contractAddress != address(0x0), "invalid address");
        allowedContracts[contractAddress] = allowed;
        emit AllowlistUpdated(contractAddress, allowed);
    }

    //========== Order Functions ==========

    function createOrder(Order memory order) public payable {
        //transfer order fee to feeRecipient address
        require(msg.value == orderFee, "invalid order fee");
        if (orderFee > 0) {
            (bool feeSuccess, ) = feeRecipient.call{value: orderFee}("");
            require(feeSuccess, "order fee transfer failed");
        }

        _createOrder(order.offered, order.requested, order.recipient, order.expiration);
    }

    function createOrderBatch(Order[] memory orders) public payable {
        require(orders.length > 0, "invalid batch size");

        //transfer order fee to feeRecipient address
        uint256 feeTotal = orderFee * orders.length;
        require(msg.value == feeTotal, "invalid order fee");
        if (orderFee > 0) {
            (bool feeSuccess, ) = feeRecipient.call{value: feeTotal}("");
            require(feeSuccess, "order fee transfer failed");
        }

        for (uint i = 0; i < orders.length; i++) {
            _createOrder(orders[i].offered, orders[i].requested, orders[i].recipient, orders[i].expiration);
        }
    }

    function cancelOrder(bytes32 orderHash) public {
        _cancelOrder(orderHash);
    }

    function cancelOrderBatch(bytes32[] memory orderHashes) public {
        require(orderHashes.length > 0, "invalid batch size");

        for (uint i = 0; i < orderHashes.length; i++) {
            _cancelOrder(orderHashes[i]);
        }
    }

    function fulfillOrder(bytes32 orderHash) public {
        _fulfillOrder(orderHash);
    }

    function fulfillOrderBatch(bytes32[] memory orderHashes) public {
        require(orderHashes.length > 0, "invalid batch size");

        for (uint i = 0; i < orderHashes.length; i++) {
            _fulfillOrder(orderHashes[i]);
        }
    }

    //========== Utility Functions ==========

    function computeOrderHash(OrderItem memory offered, OrderItem memory requested) public pure returns (bytes32) {
        return keccak256(abi.encode(offered, requested));
    }

    function orderExists(bytes32 orderHash) public view returns (bool) {
        return orderbook[orderHash].creator != address(0x0);
    }

    function isOrderValid(bytes32 orderHash) public view returns (bool) {
        if (!orderExists(orderHash)) return false;

        Order memory existingOrder = orderbook[orderHash];

        // if (!allowedContracts[existingOrder.offered.contractAddress]) return false;
        // if (!allowedContracts[existingOrder.requested.contractAddress]) return false;
        if (block.timestamp >= existingOrder.expiration) return false;

        //check offered side
        if (existingOrder.offered.contractType == ContractType.ERC20) {
            IERC20 erc20Contract = IERC20(existingOrder.offered.contractAddress);
            if (erc20Contract.balanceOf(existingOrder.creator) < existingOrder.offered.amountOrTokenId) return false;
            if (erc20Contract.allowance(existingOrder.creator, address(this)) < existingOrder.offered.amountOrTokenId) return false;
        } else if (existingOrder.offered.contractType == ContractType.ERC721) {
            IERC721 erc721Contract = IERC721(existingOrder.offered.contractAddress);
            if (erc721Contract.ownerOf(existingOrder.offered.amountOrTokenId) != existingOrder.creator) return false;
            if (erc721Contract.getApproved(existingOrder.offered.amountOrTokenId) != address(this) && !erc721Contract.isApprovedForAll(existingOrder.creator, address(this))) return false;
        }

        return true;
    }

    //========== Internal Functions ==========

    function _createOrder(OrderItem memory offered, OrderItem memory requested, address recipient, uint256 expiration) internal {
        require(msg.sender != recipient, "cannot create order for self");
        // require(allowedContracts[offered.contractAddress], "offered contract address not allowed");
        // require(allowedContracts[requested.contractAddress], "requested contract address not allowed");
        require(expiration >= block.timestamp + minOrderDuration, "invalid expiration");

        bytes32 orderHash = computeOrderHash(offered, requested);
        require(!orderExists(orderHash), "order already exists");

        //validate offered side
        if (offered.contractType == ContractType.ERC20) {
            require(offered.amountOrTokenId > 0, "cannot offer zero erc20 tokens");
            IERC20 erc20Contract = IERC20(offered.contractAddress);
            require(erc20Contract.balanceOf(msg.sender) >= offered.amountOrTokenId, "insufficient erc20 funds");
            require(erc20Contract.allowance(msg.sender, address(this)) >= offered.amountOrTokenId, "exchange not allowed");
        } else if (offered.contractType == ContractType.ERC721) {
            IERC721 erc721Contract = IERC721(offered.contractAddress);
            require(erc721Contract.ownerOf(offered.amountOrTokenId) == msg.sender, "not erc721 owner");
            require(erc721Contract.getApproved(offered.amountOrTokenId) == address(this) || erc721Contract.isApprovedForAll(msg.sender, address(this)), "exchange not approved");
        }

        //validate requested side
        if (requested.contractType == ContractType.ERC20) {
            require(requested.amountOrTokenId > 0, "cannot request zero erc20 tokens");
        }

        //emplace new order
        Order memory newOrder = Order(
            offered,
            requested,
            msg.sender,
            recipient,
            expiration
        );
        orderbook[orderHash] = newOrder;

        emit OrderCreated(orderHash, offered, requested, msg.sender, recipient, expiration);
    }

    function _cancelOrder(bytes32 orderHash) internal {
        require(orderExists(orderHash), "order not found");
        require(orderbook[orderHash].creator == msg.sender || hasRole(EXCHANGE_ADMIN, msg.sender), "not order creator or exchange admin");
        delete orderbook[orderHash];
        emit OrderCancelled(orderHash, msg.sender);
    }

    function _fulfillOrder(bytes32 orderHash) internal {
        require(isOrderValid(orderHash), "order is invalid");

        Order memory existingOrder = orderbook[orderHash];

        if (existingOrder.recipient != address(0x0)) {
            require(existingOrder.recipient == msg.sender, "only recipient can fulfill order");
        } else {
            require(existingOrder.creator != msg.sender, "cannot fulfill own order");
        }

        //validate requested side
        if (existingOrder.requested.contractType == ContractType.ERC20) {
            IERC20 erc20Contract = IERC20(existingOrder.requested.contractAddress);
            require(erc20Contract.balanceOf(msg.sender) >= existingOrder.requested.amountOrTokenId, "insufficient erc20 funds");
            require(erc20Contract.allowance(msg.sender, address(this)) >= existingOrder.requested.amountOrTokenId, "exchange not allowed");
        } else if (existingOrder.requested.contractType == ContractType.ERC721) {
            IERC721 erc721Contract = IERC721(existingOrder.requested.contractAddress);
            require(erc721Contract.ownerOf(existingOrder.requested.amountOrTokenId) == msg.sender, "not erc721 owner");
            require(erc721Contract.getApproved(existingOrder.requested.amountOrTokenId) == address(this) || erc721Contract.isApprovedForAll(msg.sender, address(this)), "exchange not approved");
        }

        delete orderbook[orderHash];

        //transfer offered to fulfiller
        if (existingOrder.offered.contractType == ContractType.ERC20) {
            IERC20(existingOrder.offered.contractAddress).transferFrom(existingOrder.creator, msg.sender, existingOrder.offered.amountOrTokenId);
        } else if (existingOrder.offered.contractType == ContractType.ERC721) {
            IERC721(existingOrder.offered.contractAddress).transferFrom(existingOrder.creator, msg.sender, existingOrder.offered.amountOrTokenId);
        }

        //transfer requested to creator
        if (existingOrder.requested.contractType == ContractType.ERC20) {
            IERC20(existingOrder.requested.contractAddress).transferFrom(msg.sender, existingOrder.creator, existingOrder.requested.amountOrTokenId);
        } else if (existingOrder.requested.contractType == ContractType.ERC721) {
            IERC721(existingOrder.requested.contractAddress).transferFrom(msg.sender, existingOrder.creator, existingOrder.requested.amountOrTokenId);
        }

        emit OrderFulfilled(orderHash, msg.sender);
    }

    // receive() external payable {}
    // fallback() external payable {}
}