// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE 20 Factory interface definition
 */
interface IOGRE20Factory {
    function produceOGRE20(string memory name, string memory symbol, address owner) external returns (address);
}