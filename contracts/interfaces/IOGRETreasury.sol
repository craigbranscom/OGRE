// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @notice OGRE Treasury interface definition
 */
interface IOGRETreasury {
    function daoAddress() external view returns (address);
    function sendERC721(address to, address erc721Contract, uint256 tokenId) external;
    // function depositNative() external payable;
    // function withdrawNative(address to, uint256 amount) external;
}