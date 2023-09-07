// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../ERC721Receivable.sol";

/**
 * @title Stub ERC721Receivable Contract used in unit testing.
 */
contract StubERC721Receivable is ERC721Receivable {
    
    constructor() {}

    function sendERC721(address to, uint256 tokenId, address erc721Contract) public {
        _sendERC721(to, tokenId, erc721Contract);
    }

    receive() external payable {}

}