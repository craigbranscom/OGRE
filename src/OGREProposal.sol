// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IOGREDAO.sol";
import {Enums} from "./libraries/Enums.sol";
import {Structs} from "./libraries/Structs.sol";

/**
 * @title Open Governance Referendum Engine Proposal Contract
 * @author Craig Branscom
 */
contract OGREProposal is Ownable {

    //========== State ==========

    address public immutable daoAddress; //dao whose members are allowed to cast votes on proposal

    bool public revotable; //allows members to change their votes during voting period
    string public proposalMetadata; //metadata link to information about proposal
    
    Enums.ProposalStatus public status; //proposed, cancelled, failed, passed, executed (cancelled, failed, and executed are terminal states)
    uint256 public startTime; //start of vote period (unix timestamp)
    uint256 public endTime; //end of vote period (unix timestamp)
    uint256 public voteCount; //number of tokens that have cast a vote
    uint256[3] public voteTotals; //[0, 0, 0] == no, yes, abstain
    mapping(uint256 => Structs.Vote) public votes; //token id => vote struct
    Structs.Action[] private actions; //actions to load (in order) if proposal passes

    //========== Events ==========

    /**
     * @notice Logs a change in proposal status.
     * @param previousStatus previous status of proposal
     * @param newStatus new status of proposal
     */
    event StatusUpdated(Enums.ProposalStatus previousStatus, Enums.ProposalStatus newStatus);

    /**
     * @notice Logs a vote.
     * @param voter address that cast the vote
     * @param tokenId id of nft token granting vote
     * @param vote direction of vote (0 = NO, 1 = YES, 2 = ABSTAIN)
     */
    event VoteCast(address voter, uint256 tokenId, Enums.VoteDirection vote);

    /**
     * @notice Logs a successful evaluation of proposal results.
     * @param quorumPassed true if proposal passed dao quorum threshold
     * @param supportPassed true if proposal passed dao support threshold
     * @param totalVotes final vote count on proposal
     */
    event ProposalEvaluated(bool quorumPassed, bool supportPassed, uint256 totalVotes, uint256 quorumVotesThreshold, uint256 supportVotesThreshold);

    //========== Errors ==========

    error InvalidAddress(string variableName, address value);
    error InvalidProposalStatus(Enums.ProposalStatus currentStatus, Enums.ProposalStatus requiredStatus);
    error InvalidMemberStatus(Enums.MemberStatus currentStatus, Enums.MemberStatus requiredStatus);
    error InvalidVoteDirection(Enums.VoteDirection vote);
    error InvalidTokenOwner(uint256 tokenId, address owner);
    error StartTimeInPast();
    error EndTimeBeforeStartTime();
    error InvalidVoteDuration();
    error NotRevotable();

    //========== Constructor ==========

    /**
     * @dev Creates proposal.
     * @param proposalMetadata_ metadata link to information about proposal
     * @param daoAddress_ address of dao 
     * @param owner_ address of owner
     */
    constructor(string memory proposalMetadata_, address daoAddress_, address owner_) Ownable(owner_) {
        if (daoAddress_ == address(0x0)) revert InvalidAddress("daoAddress_", daoAddress_);

        daoAddress = daoAddress_;
        proposalMetadata = proposalMetadata_;

        emit StatusUpdated(Enums.ProposalStatus.PROPOSED, Enums.ProposalStatus.PROPOSED);
    }

    //========== Modifiers ==========

    /**
     * @dev Reverts if sender is not dao address
     */
    modifier onlyDAO {
        require(msg.sender == daoAddress, "caller must be dao");
        _;
    }

    /**
     * @dev Reverts if past vote start period
     */
    modifier onlyPreVote {
        require(startTime == 0 || block.timestamp < startTime, "must be pre vote period");
        _;
    }

    //========== Configuration ==========

    /**
     * @dev Sets proposal metadata.
     * @param newProposalMetadata new proposal metadata
     */
    function setProposalMetadata(string memory newProposalMetadata) public onlyOwner onlyPreVote {
        proposalMetadata = newProposalMetadata;
    }

    /**
     * @dev Sets whether proposal is revotable.
     * @param isRevotable allows revoting on proposal if true
     */
    function setRevotable(bool isRevotable) public onlyOwner onlyPreVote {
        revotable = isRevotable;
    }

    /**
     * @dev Sets voting start and end time
     * @param newStartTime time voting will start
     * @param newEndTime time voting will end
     */
    function setVotingPeriod(uint256 newStartTime, uint256 newEndTime) public onlyOwner onlyPreVote {
        if (newStartTime < block.timestamp) revert StartTimeInPast();
        if (newEndTime <= newStartTime) revert EndTimeBeforeStartTime();
        if (newEndTime - newStartTime < IOGREDAO(daoAddress).minVoteDuration()) revert InvalidVoteDuration();

        startTime = newStartTime;
        endTime = newEndTime;
    }

    /**
     * @dev Pushes a new action to the end of the actions queue
     */
    function addAction(address target, uint256 value, string memory sig, bytes memory data) public onlyOwner onlyPreVote {
        //ready is set as zero when added, gets ready time set when loaded into action hopper
        Structs.Action memory act = Structs.Action(target, value, sig, data, 0);
        actions.push(act);
    }

    /**
     * @dev Removes action at end of action queue
     */
    function removeAction() public onlyOwner onlyPreVote {
        actions.pop();
    }

    /**
     * @dev Returns number of actions in proposal.
     * @return uint256 of actions in proposal
     */
    function getActionCount() public view returns (uint256) {
        return actions.length;
    }

    /**
     * @dev Returns action at index.
     * @param index index of action
     * @return Action action at index
     */
    function getAction(uint256 index) public view returns (Structs.Action memory) {
        return actions[index];
    }

    //========== Voting ==========

    /**
     * @dev casts a vote
     * @param tokenId id of token casting votes
     * @param vote number representing vote (0 = NO, 1 = YES, 2 = ABSTAIN)
     */
    function castVote(uint256 tokenId, Enums.VoteDirection vote) public {
        //validate
        if (status != Enums.ProposalStatus.PROPOSED) revert InvalidProposalStatus(status, Enums.ProposalStatus.PROPOSED);
        if (IOGREDAO(daoAddress).getMemberStatus(tokenId) != Enums.MemberStatus.REGISTERED) {
            revert InvalidMemberStatus(IOGREDAO(daoAddress).getMemberStatus(tokenId), Enums.MemberStatus.REGISTERED);
        }
        if (IERC721(daoAddress).ownerOf(tokenId) != msg.sender) revert InvalidTokenOwner(tokenId, msg.sender);
        if (vote > Enums.VoteDirection(2)) revert InvalidVoteDirection(vote);
        require(block.timestamp >= startTime, "must be after start time");
        require(block.timestamp <= endTime, "must be before end time");

        //existing vote not found
        uint8 voteDirectionIdx = uint8(vote);
        if (!votes[tokenId].voted) {
            voteCount += 1;
            voteTotals[voteDirectionIdx] += 1;
        } else { //existing vote found
            if (!revotable) revert NotRevotable();
            voteTotals[uint8(votes[tokenId].direction)] -= 1; //undo previous vote
            voteTotals[voteDirectionIdx] += 1; //apply new vote
        }

        votes[tokenId].direction = vote;
        votes[tokenId].voted = true;

        emit VoteCast(msg.sender, tokenId, vote);
    }

    /**
     * @dev Returns vote for token id.
     * @param tokenId id of token
     * @return Vote vote for token id
     */
    function getVote(uint256 tokenId) public view returns (Structs.Vote memory) {
        return votes[tokenId];
    }

    //========== Proposal Lifecycle ==========

    /**
     * @dev Cancels proposal.
     */
    function cancelProposal() public onlyOwner {
        if (status != Enums.ProposalStatus.PROPOSED) revert InvalidProposalStatus(status, Enums.ProposalStatus.PROPOSED);
        _updateStatus(Enums.ProposalStatus.CANCELLED);
    }

    function setActionReady(uint256 index, uint256 readyTime) external onlyDAO {
        // require(getActionCount() > 0, "no actions to update");
        // require(index <= getActionCount() - 1, "no action at index");
        // require(readyTime > block.timestamp, "ready time must be in the future");
        actions[index].ready = readyTime;
    }

    /**
     * @dev Updates proposal status.
     * @param newStatus new status of proposal
     */
    function _updateStatus(Enums.ProposalStatus newStatus) internal {
        emit StatusUpdated(status, newStatus);
        status = newStatus;
    }

}