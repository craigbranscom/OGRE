// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title allows children to receive and withdraw erc721 and maintain balances of depositors
 */
abstract contract ERC721Depositable is IERC721Receiver {

    mapping(address => bool) public allowedERC721Contracts; //erc721 contract address => allowed?
    mapping(address => mapping(uint256 => bool)) private _erc721Deposits; //depositor address => (token id => true if deposited)
    
    /**
     * @dev logs deposit of erc721 token
     * @param from address sending the token
     * @param tokenId id of token sent
     * @param erc721Contract address of erc721 contract
     */
    event ERC721Deposited(address from, uint256 tokenId, address erc721Contract);

    /**
     * @dev logs withdrawal of erc721 tokens
     * @param to address receiving the withdrawn token
     * @param tokenId id of token being withdrawn
     * @param erc721Contract address of erc721 contract
     */
    event ERC721Withdrawn(address to, uint256 tokenId, address erc721Contract);

    constructor() {}

    function allowERC721Contract(address erc721Contract) public {
        require(allowedERC721Contracts[erc721Contract] == false, "erc721 contract address already allowed");
        allowedERC721Contracts[erc721Contract] = true;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public override returns (bytes4) {
        require(allowedERC721Contracts[msg.sender], "contract is not allowed");
        _erc721Deposits[from][tokenId] = true;
        emit ERC721Deposited(from, tokenId, msg.sender);
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdrawERC721(uint256 tokenId, address erc721Contract) public {
        require(_erc721Balances[msg.sender][tokenId], "not erc721 token owner");
        delete _erc721Balances[msg.sender][tokenId];
        IERC721(erc721Contract).safeTransferFrom(address(this), msg.sender, tokenId);
        emit ERC721Withdrawn(msg.sender, tokenId, erc721Contract);
    }
}