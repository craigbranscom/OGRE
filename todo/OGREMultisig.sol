// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract OGREMultisig {
    uint256 public nonce;
    address[] public _signers;

    constructor(address[] memory signers_) {
        _signers = signers_;
    }

    function executeMultisig(address receiver, uint256 value, bytes memory data, bytes32[] memory r, bytes32[] memory s, uint8[] memory v) external {
        bytes32 hashed = prefixed(keccak256(abi.encodePacked(address(this), receiver, value, data, nonce)));

        //check for signatures of all signers
        for (uint256 i = 0; i < _signers.length; i++) {
            //recover signer
            address recovered = ecrecover(hashed, v[i], r[i], s[i]);
            
            //validate
            require(recovered == _signers[i]);
        }

        nonce += 1;
        (bool success, bytes memory data) = receiver.call{value: value}(data);
        require(success, "call unsuccessful");
    }

    //builds a prefixed hash to mimic the behavior of eth_sign
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32", hash));
    }
}