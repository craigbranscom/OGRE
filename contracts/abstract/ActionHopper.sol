// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @title Action Hopper Contract
 */
abstract contract ActionHopper {

    uint256 public delay; //seconds that must elapse after action is loaded to be considered ready
    mapping(bytes32 => bool) public loadedActions;
    
    /**
     * @dev logs an action being loaded into hopper
     * @param trxHash hash of target + value + sig + data + ready
     * @param target address of target contract
     * @param value amount of value to send when executed
     * @param sig signature data
     * @param data additional data to send
     * @param ready unix time point when action can be executed
     */
    event ActionLoaded(bytes32 trxHash, address target, uint256 value, string sig, bytes data, uint256 ready);

    /**
     * @dev logs an action being cancelled and removed from hopper
     * @param trxHash hash of target + value + sig + data + ready
     * @param target address of target contract
     * @param value amount of value to send when executed
     * @param sig signature data
     * @param data additional data to send
     * @param ready unix time point when action can be executed
     */
    event ActionCancelled(bytes32 trxHash, address target, uint256 value, string sig, bytes data, uint256 ready); 

    /**
     * @dev logs an action being executed and removed from hopper
     * @param trxHash hash of target + value + sig + data + ready
     * @param target address of target contract
     * @param value amount of value to send when executed
     * @param sig signature data
     * @param data additional data to send
     * @param ready unix time point when action can be executed
     */
    event ActionExecuted(bytes32 trxHash, address target, uint256 value, string sig, bytes data, uint256 ready);

    /**
     * @dev throws if an action is not ready when attempting to execute
     * @param trxHash hash of target + value + sig + data + ready
     * @param currentTime block timestamp during execution
     * @param readyTime timestamp when action is ready
     */
    error ActionNotReady(bytes32 trxHash, uint256 currentTime, uint256 readyTime);

    /**
     * @dev throws if an action has not been loaded when attempting to execute
     * @param trxHash hash of target + value + sig + data + ready
     */
    error ActionNotLoaded(bytes32 trxHash);

    /**
     * @dev throws if an action failed during execution
     * @param trxHash hash of target + value + sig + data + ready
     * @param returnData data returned from call
     */
    error ActionExecutionFailed(bytes32 trxHash, bytes returnData);
    
    constructor(uint256 delay_) {
        delay = delay_;
    }

    /**
     * @dev returns true if action has been loaded into hopper
     * @param target address of target contract
     * @param value amount of value to send
     * @param sig signature data
     * @param data additional data to send
     * @param ready unix time point when action can be executed
     */
    function isActionLoaded(address target, uint256 value, string memory sig, bytes memory data, uint256 ready) public view returns (bool) {
        bytes32 trxHash = keccak256(abi.encode(target, value, sig, data, ready));
        return loadedActions[trxHash];
    }

    /**
     * @dev updates delay value
     * @param newDelay new delay value (in seconds)
     */
    function _setDelay(uint256 newDelay) internal {
        delay = newDelay;
    }

    /**
     * @dev loads an action into the hopper
     * @param target address of target contract
     * @param value amount of value to send
     * @param sig signature data
     * @param data additional data to send
     */
    function _loadAction(address target, uint256 value, string memory sig, bytes memory data) internal returns (uint256) {
        uint256 ready = block.timestamp + delay;

        bytes32 trxHash = keccak256(abi.encode(target, value, sig, data, ready));
        loadedActions[trxHash] = true;

        emit ActionLoaded(trxHash, target, value, sig, data, ready);

        return ready;
    }

    /**
     * @dev cancels an action and removes from hopper
     * @param target address of target contract
     * @param value amount of value to send
     * @param sig signature data
     * @param data additional data to send
     * @param ready unix time point when action can be executed
     */
    function _cancelAction(address target, uint256 value, string memory sig, bytes memory data, uint256 ready) internal {
        bytes32 trxHash = keccak256(abi.encode(target, value, sig, data, ready));
        delete loadedActions[trxHash];

        emit ActionCancelled(trxHash, target, value, sig, data, ready);
    }

    /**
     * @dev executes an action and removes from hopper
     * @param target address of target contract
     * @param value amount of value to send
     * @param sig signature data
     * @param data additional data to send
     * @param ready unix time point when action can be executed
     */
    function _executeAction(address target, uint256 value, string memory sig, bytes memory data, uint256 ready) internal returns (bytes memory) {
        bytes32 trxHash = keccak256(abi.encode(target, value, sig, data, ready));

        if (!loadedActions[trxHash]) revert ActionNotLoaded(trxHash);
        if (block.timestamp <= ready) revert ActionNotReady(trxHash, block.timestamp, ready);
        
        delete loadedActions[trxHash];
        bytes memory callData;

        if (bytes(sig).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(sig))), data);
        }

        emit ActionExecuted(trxHash, target, value, sig, data, ready);

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        if (!success) revert ActionExecutionFailed(trxHash, returnData);

        return returnData;
    }

}