// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// import "hardhat/console.sol";

/**
 * @title Open Governance Referendum Engine NFT Contract
 */
contract SampleERC721 is Ownable, Pausable, ERC721 {
    
    constructor(string memory name_, string memory symbol_, address owner_) Ownable(owner_) ERC721(name_, symbol_) {}

    /**
     * @dev mint token id
     */
    function mint(address to, uint256 tokenId) public payable onlyOwner whenNotPaused {
        _safeMint(to, tokenId);
    }

    /**
     * @dev burn token id
     */
    function burn(uint256 tokenId) public onlyOwner whenNotPaused {
        _burn(tokenId);
    }
}