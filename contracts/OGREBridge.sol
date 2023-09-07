// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract OGREBridge is Ownable, Pausable {

    mapping(uint256 => bool) public approvedChains;
    mapping(address => bool) public approvedContracts;
    mapping(address => bool) public blockedAcounts;

    event ChainApproval(uint256 chainId, bool approved);
    event ContractApproval(address nftAddress, bool approved);
    event AccountBlock(address account, bool blocked);
    event ItemDeposited(address nftAddress, uint256 tokenId, address depositor, uint256 destinationChainId);
    event ItemWithdrawn(address nftAddress, uint256 tokenId, address recipient);
    
    constructor(address owner_) {
        transferOwnership(owner_);
    }

    function toggleApprovedChain(uint256 chainId) public onlyOwner {
        approvedChains[chainId] = !approvedChains[chainId];
        emit ChainApproval(chainId, approvedChains[chainId]);
    }

    function toggleApprovedContract(address nftAddress) public onlyOwner {
        approvedContracts[nftAddress] = !approvedContracts[nftAddress];
        emit ContractApproval(nftAddress, approvedContracts[nftAddress]);
    }

    function toggleBlockedAccount(address account) public onlyOwner {
        blockedAcounts[account] = !blockedAcounts[account];
        emit AccountBlock(account, blockedAcounts[account]);
    }

    function depositItem(address nftAddress, uint256 tokenId, address depositor, uint256 destinationChainId) public whenNotPaused {
        require(nftAddress != address(0x0), "nftAddress cannot be zero");
        require(msg.sender == depositor, "depositor must be caller");

        //TODO: transfer item to bridge

        emit ItemDeposited(nftAddress, tokenId, depositor, destinationChainId);
    }

    function withdrawItem(address nftAddress, uint256 tokenId, address recipient) public onlyOwner whenNotPaused {
        //TODO: validate
        //TODO: transfer item to recipient
        emit ItemWithdrawn(nftAddress, tokenId, recipient);
    }

    // function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
    //     // require(_incomingOrderItem.contractAddress != address(0x0), "not expecting incoming order item");
    //     // require(_incomingOrderItem.itemType == ItemType.ERC721, "wrong item type sent");
    //     // require(IERC721(from).ownerOf(tokenId) == address(this), "item not received");
    //     // if (data.length > 0) {}
    //     // IERC721(from).approve(msg.sender, tokenId);
    //     return IERC721Receiver.onERC721Received.selector;
    // }
}