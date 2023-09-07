// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "../node_modules/@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
// import "./abstract/NativeReceivable.sol";

/**
 * @title Open Governance Referendum Engine Treasury Contract
 */
contract OGRETreasury is Ownable, Pausable {

    address public immutable daoAddress;
    
    constructor(address daoAddress_) {
        daoAddress = daoAddress_;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        // require(_incomingOrderItem.contractAddress != address(0x0), "not expecting incoming order item");
        // require(_incomingOrderItem.itemType == ItemType.ERC721, "wrong item type sent");
        // require(IERC721(from).ownerOf(tokenId) == address(this), "item not received");
        // if (data.length > 0) {}
        // IERC721(from).approve(msg.sender, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }

    function sendERC721(address to, address erc721Contract, uint256 tokenId) public {
        // require(_erc721Balances[erc721Contract][tokenId], "erc721 token not owned");
        // delete _erc721Balances[erc721Contract][tokenId];
        IERC721(erc721Contract).safeTransferFrom(address(this), to, tokenId);
        // emit ERC721Sent(to, tokenId, erc721Contract);
    }

    receive() external payable {}

    fallback() external {}

}