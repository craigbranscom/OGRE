// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/OGREDAO.sol";

contract OGRETest is Test {
    OGREDAO public dao;

    function setUp() public {
        dao = new OGREDAO("TestName", "TestMeta", address(this), address(this), 1, address(this), 500);
    }

    function testExample() public {
        assertTrue(true);
    }
} 