// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE NFT Factory interface definition
 */
interface IOGRE721Factory {
    function produceOGRE721(string memory name, string memory symbol, address owner) external returns (address);
}