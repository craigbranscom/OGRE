// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @title Open Governance Referendum Engine Committee Contract
/// @author Craig Branscom
contract OGRECommittee {

    /// @dev reverts if not org address
    modifier onlyOrg {
        require(msg.sender == orgAddress, "must be org address");
        _;
    }

    /// @dev reverts if not seat holder
    modifier onlySeatHolder {
        require(_seats[msg.sender], "must be seat holder");
        _;
    }

    address public immutable orgAddress;

    uint256 public committeeSize;
    // uint256 private _committeeFunds;

    mapping(address => bool) private _seats;
    mapping(uint256 => address) public seats;

    /// @notice logs a completed seat filling
    /// @param seatId id of seat filled
    /// @param seatHolder address holding the seat
    event SeatFilled(uint256 seatId, address seatHolder);

    constructor(uint256 committeeSize_) {
        committeeSize = committeeSize_;
        orgAddress = msg.sender;
    }

    /// @notice returns true if an address is a seat holder
    /// @param holder address to check
    function isSeatHolder(address holder) public view returns (bool) {
        return _seats[holder];
    }

    /// @notice sets a new committee size
    /// @param newSize new number of seats on committee
    function setSize(uint256 newSize) public onlyOrg {
        committeeSize = newSize;

        //TODO: zero out seats above size?
    }

    /// @notice updates seat id with new address
    /// @param seatId id of seat to update
    /// @param seatHolder address of new seat holder
    function setSeat(uint256 seatId, address seatHolder) public onlyOrg {
        _seats[seatHolder] = true;
        seats[seatId] = seatHolder;

        //TODO: check existing seat and undo in state
    }

}