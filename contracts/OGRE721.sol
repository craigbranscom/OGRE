// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
// import "../node_modules/@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";

// import "hardhat/console.sol";

/**
 * @title Open Governance Referendum Engine NFT Contract
 */
contract OGRE721 is Ownable, Pausable, ERC721 {
    
    constructor(string memory name_, string memory symbol_, address owner_) ERC721(name_, symbol_) {
        transferOwnership(owner_);
    }

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