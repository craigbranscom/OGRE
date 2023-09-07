// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

//TODO: check linked ERC20 address is actually an erc20 contract

/// @title Open Governance Referendum Engine Lock Contract
/// @notice Contract to allow fungible tokens to be locked and turned into NFTs.
/// @author Craig Branscom
contract OGRELock is Ownable, Pausable, ERC721Enumerable {

    address immutable erc20Contract; //linked fungible token contract
    uint256 immutable lockAmount; //in tokens
    uint256 immutable lockTime; //in seconds

    uint256 mintCount;
    uint256 burnCount;

    mapping(uint256 => uint256) public locks; //token id -> unlock time

    constructor(string memory name_, string memory symbol_, address erc20Contract_, uint256 lockAmount_, uint256 lockTime_) ERC721(name_, symbol_) {
        erc20Contract = erc20Contract_;
        lockAmount = lockAmount_;
        lockTime = lockTime_;
    }

    /// @notice mints a new token
    /// @dev mints new token to `to` address. Reverts if erc20 tokens are not approved. Mints
    /// token ids starting at 1.
    /// @param to address to receive the newly minted nft
    function mint(address to) public {
        //validate
        require(to == address(0x0), "cannot mint to zero address");

        mintCount += 1;

        //transfer approved fungible tokens
        IERC20(erc20Contract).transferFrom(msg.sender, address(this), lockAmount);

        //TODO: set lock

        _safeMint(to, mintCount);
    }

    /// @notice burns an existing token
    /// @dev burns the `tokenId` token.
    function burn(uint256 tokenId) public {
        //validate
        // require(mintCount <= tokenId, "token id not found");

        //transfer locked tokens to sender
        //TODO: change to transferFrom?
        IERC20(erc20Contract).transfer(msg.sender, lockAmount);

        //clear out lock
        delete locks[tokenId];

        burnCount += 1;

        _burn(tokenId);
    }

}