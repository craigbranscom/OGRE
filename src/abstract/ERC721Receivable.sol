// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//TODO: remove allowlist logic? split into allowlist and blocklist?
//TODO: remove inventory tracking logic? could call balanceOf() instead?

/**
 * @title ERC721 Receivable Contract
 * @author Craig Branscom
 * @notice Allows inherited contracts to send and receive ERC721 tokens.
 */
abstract contract ERC721Receivable is IERC721Receiver {

    // mapping(address => bool) public allowedERC721Contracts; //erc721 contract address => true if allowed
    // mapping(address => mapping(uint256 => bool)) private _erc721Balances; //erc721 address => (token id => true if owned)
    
    event ERC721Received(address from, uint256 tokenId, address erc721Contract);
    event ERC721Sent(address to, uint256 tokenId, address erc721Contract);

    constructor() {}

    // function _allowERC721Contract(address erc721Contract) internal {
    //     require(allowedERC721Contracts[erc721Contract] == false, "contract already allowed");
    //     allowedERC721Contracts[erc721Contract] = true;
    // };

    /**
     * @notice Receives an ERC721 token.
     * @param operator address of operator
     * @param from address of sender
     * @param tokenId id of token
     */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata) external virtual override returns (bytes4) {
        // require(allowedERC721Contracts[from], "contract is not allowed");
        // require(_erc721Balances[from][tokenId] == false, "erc721 token already owned");
        // _erc721Balances[from][tokenId] = true;
        emit ERC721Received(operator, tokenId, from);
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @notice Sends an ERC721 token to a recipient.
     * @param to address of recipient
     * @param tokenId id of token to send
     * @param erc721Contract address of ERC721 contract
     * @param data data to send with the token
     */
    function _sendERC721(address to, uint256 tokenId, address erc721Contract, bytes calldata data) internal {
        // require(_erc721Balances[erc721Contract][tokenId], "erc721 token not owned");
        // delete _erc721Balances[erc721Contract][tokenId];
        IERC721(erc721Contract).safeTransferFrom(address(this), to, tokenId, data);
        emit ERC721Sent(to, tokenId, erc721Contract);
    }
}