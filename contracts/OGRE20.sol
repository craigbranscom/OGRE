// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Open Governance Referendum Engine ERC20 Contract
 */
contract OGRE20 is Ownable, Pausable, ERC20 {
    
    constructor(string memory name_, string memory symbol_, address owner_) ERC20(name_, symbol_) {
        transferOwnership(owner_);
    }

    /**
     * @dev mint token amount
     */
    function mint(address to, uint256 amount) public payable onlyOwner whenNotPaused {
        _mint(to, amount);
    }

    /**
     * @dev burn token amount
     */
    function burn(address from, uint256 amount) public onlyOwner whenNotPaused {
        _burn(from, amount);
    }
}