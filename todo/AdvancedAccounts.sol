// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract AdvancedAccounts {

    string public constant RECOVER_PERMISSION_NAME = "Recover";
    string public constant EMPTY_PERMISSION_NAME = "";

    bytes32 public constant RECOVER_NAME_HASH = keccak256(abi.encodePacked("Recover"));

    struct Permission {
        address actor;
        bytes32 parent;
    }

    mapping(address => mapping(bytes32 => Permission)) public accounts; //accountAddress => permissionName => Permission

    event AccountInitialized(address accountAddress);
    event PermissionCreated(address accountAddress, string permissionName, address actor, string parentName);
    event ActorUpdated(address accountAddress, string permissionName, address newActor);
    
    constructor() {}

    function initializeAccount(address recoverAddress) public payable {
        require(accounts[msg.sender][RECOVER_NAME_HASH].actor == address(0x0), "account already initialized");

        Permission memory perm = Permission({
            actor: recoverAddress,
            parent: bytes32(0)
        });

        accounts[msg.sender][RECOVER_NAME_HASH] = perm;

        emit AccountInitialized(msg.sender);
    }

    function createPermission(string memory permissionName, address actor, string memory parent) public {
        require(accounts[msg.sender][RECOVER_NAME_HASH].actor != address(0x0), "account not initialized");
        bytes32 permissionNameHash = hashPermissionName(permissionName);
        require(accounts[msg.sender][permissionNameHash].actor == address(0x0), "permission already created");
        require(actor != address(0x0), "invalid actor");
        // require(hashPermissionName(parent) != bytes32(0), "invalid parent");

        Permission memory perm = Permission({
            actor: actor,
            parent: permissionNameHash
        });

        accounts[msg.sender][permissionNameHash] = perm;

        emit PermissionCreated(msg.sender, permissionName, actor, parent);
    }

    function updateActor(string memory permissionName, address actor) public {
        require(msg.sender == getPermissionActor(msg.sender, permissionName) || msg.sender == getPermissionParentActor(msg.sender, permissionName), "not permission actor or parent");

        accounts[msg.sender][hashPermissionName(permissionName)].actor = actor;

        emit ActorUpdated(msg.sender, permissionName, actor);
    }

    function hashPermissionName(string memory permissionName) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(permissionName));
    }

    function getPermissionActor(address accountAddress, string memory permissionName) public view returns (address) {
        return accounts[accountAddress][hashPermissionName(permissionName)].actor;
    }

    function getPermissionParentActor(address accountAddress, string memory permissionName) public view returns (address) {
        bytes32 parentHash = accounts[accountAddress][hashPermissionName(permissionName)].parent;
        return accounts[accountAddress][parentHash].actor;
    }

    function isPermissionActor(address actor, address accountAddress, string memory permissionName) public view returns (bool) {
        return getPermissionActor(accountAddress, permissionName) == actor;
    }

    //========== Internal Functions ==========

    function _getPermissionActor(address accountAddress, bytes32 permissionNameHash) internal view returns (address) {
        return accounts[accountAddress][permissionNameHash].actor;
    }

    function _getPermissionParentActor(address accountAddress, bytes32 permissionNameHash) internal view returns (address) {
        bytes32 parentHash = accounts[accountAddress][permissionNameHash].parent;
        return accounts[accountAddress][parentHash].actor;
    }
    
}