// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

// import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
// import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
// import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./contracts/interfaces/IOGRE721.sol";

contract OGRETokenizedSocial {

    struct Handle {
        string handle;
    }

    struct Profile {
        uint256 handleTokenId;
    }

    // struct Follow {
    //     uint256 followedProfileTokenId;
    //     uint256 followerProfileTokenId;
    // }

    struct Post {
        uint256 profileTokenId;
        string contentHash;
        // string threadHash;
    }

    // address public handleContractAddress;
    address public profileContractAddress;
    address public followContractAddress;
    address public postContractAddress;

    uint256 private _nextProfileTokenId = 1;
    uint256 private _nextFollowTokenId = 1;
    uint256 private _nextPostTokenId = 1;

    mapping(uint256 => Handle) public handles; //handleTokenId => Handle

    mapping(uint256 => uint256) public follows; //followerTokenId => followedTokenId

    mapping(uint256 => Post) public posts; //postTokenId => Post
    
    constructor() {}

    function createProfile() public payable {
        IOGRE721(profileContractAddress).mint(msg.sender, _nextProfileTokenId);
        _nextProfileTokenId += 1;
    }

    function followProfile(uint256 followedProfileTokenId, uint256 followerProfileTokenId) public payable {
        require(IERC721(profileContractAddress).ownerOf(followerProfileTokenId) == msg.sender, "sender not follower");
    }

    function createPost(uint256 profileTokenId, string memory contentHash) public payable {
        IOGRE721(postContractAddress).mint(msg.sender, _nextPostTokenId);
        _nextPostTokenId += 1;
    }

    // function commitThread(uint256 postTokenId) public {}

}