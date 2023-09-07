// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../../node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

//TODO: remove allowlist logic? split into sendlist and receivelist?
//TODO: remove inventory tracking logic? could call balanceOf() instead?
//TODO: use safeTransferFrom with calldata param instead?

/**
 * @title allows children to receive and send erc721 tokens
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

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external virtual override returns (bytes4) {
        // require(allowedERC721Contracts[from], "contract is not allowed");
        // require(_erc721Balances[from][tokenId] == false, "erc721 token already owned");
        // _erc721Balances[from][tokenId] = true;
        emit ERC721Received(operator, tokenId, from);
        return IERC721Receiver.onERC721Received.selector;
    }

    function _sendERC721(address to, uint256 tokenId, address erc721Contract) internal {
        // require(_erc721Balances[erc721Contract][tokenId], "erc721 token not owned");
        // delete _erc721Balances[erc721Contract][tokenId];
        IERC721(erc721Contract).safeTransferFrom(address(this), to, tokenId);
        emit ERC721Sent(to, tokenId, erc721Contract);
    }
}