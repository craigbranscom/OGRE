// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE 721 interface definition
 */
interface IOGRE721 {
    function mint(address to, uint256 tokenId) external payable;
    function burn(uint256 tokenId) external;
}