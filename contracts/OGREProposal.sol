// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOGREDAO.sol";
import {Enums} from "./libraries/Enums.sol";
import {Structs} from "./libraries/Structs.sol";

/**
 * @title Open Governance Referendum Engine Proposal Contract
 */
contract OGREProposal is Ownable {

    /**
     * @dev reverts if sender is not dao address
     */
    modifier onlyDAO {
        require(msg.sender == daoAddress, "caller must be dao");
        _;
    }

    /**
     * @dev reverts if past vote start period
     */
    modifier onlyPreVote {
        require(startTime == 0 || block.timestamp < startTime, "must be pre vote period");
        _;
    }

    // modifier onlyPostVote {
    //     require(block.timestamp > endTime, "must be post vote period");
    //     _;
    // }

    address public immutable daoAddress; //dao whose members are allowed to cast votes on proposal

    // bool public flagged; //dao can flag proposals to indicate members should proceed with caution
    bool public revotable;
    string public proposalTitle;
    
    Enums.ProposalStatus public status; //proposed, cancelled, failed, passed, executed (cancelled, failed, and executed are terminal states)
    uint256 public voteCount; //number of tokens that have cast a vote
    uint256 public startTime; //start of vote period (unix timestamp)
    uint256 public endTime; //end of vote period (unix timestamp)
    uint256[3] public voteTotals; //[0, 0, 0] == no, yes, abstain
    mapping(uint256 => Structs.Vote) public votes; //token id => vote struct
    Structs.Action[] private actions; //actions to load (in order) if proposal passes

    /**
     * @notice logs a change in proposal status.
     * @param newStatus new status of proposal
     */
    event StatusUpdated(string newStatus);

    /**
     * @notice logs a vote
     * @param voter address that cast the vote
     * @param tokenId id of nft token granting vote
     * @param vote direction of vote (0 = NO, 1 = YES, 2 = ABSTAIN)
     */
    event VoteCast(address voter, uint256 tokenId, uint8 vote);

    /**
     * @notice logs a successful proposal evaluation
     * @param quorumPassed true if proposal passed dao quorum threshold
     * @param supportPassed true if proposal passed dao support threshold
     * @param totalVotes final vote count on proposal
     */
    event ProposalResults(bool quorumPassed, bool supportPassed, uint256 totalVotes, uint256 quorumVotesThreshold, uint256 supportVotesThreshold);

    error InvalidStatus(Enums.ProposalStatus currentStatus, Enums.ProposalStatus requiredStatus);

    constructor(string memory proposalTitle_, address daoAddress_, address owner_) {
        // require(daoAddress_ != address(0x), "daoAddress cannot be zero address");

        proposalTitle = proposalTitle_;
        daoAddress = daoAddress_;

        //transfer ownership to initial owner
        transferOwnership(owner_);

        emit StatusUpdated("Proposed");
    }

    function getActionCount() public view returns (uint256) {
        return actions.length;
    }

    function getAction(uint256 index) public view returns (Structs.Action memory) {
        return actions[index];
    }

    function getVote(uint256 tokenId) public view returns (uint8) {
        require(votes[tokenId].voted, "token has not voted");
        return votes[tokenId].direction;
    }

    function hasVoted(uint256 tokenId) public view returns (bool) {
        return votes[tokenId].voted;
    }

    function cancelProposal() public onlyOwner {
        if (status != Enums.ProposalStatus.PROPOSED) revert InvalidStatus(status, Enums.ProposalStatus.PROPOSED);
        status = Enums.ProposalStatus.CANCELLED;
        emit StatusUpdated("Cancelled");
    }

    function updateStatus(uint8 newStatus) external onlyDAO {
        // require(newStatus > uint8(status), "invalid status update");
        // require(uint8(status) != 1 && uint8(status) != 2 && uint8(status) != 4, "cannot update terminal proposal status");
        // emit StatusUpdated();
        status = Enums.ProposalStatus(newStatus);
    }

    function setActionReady(uint256 index, uint256 readyTime) external onlyDAO {
        // require(getActionCount() > 0, "no actions to update");
        // require(index <= getActionCount() - 1, "no action at index");
        // require(readyTime > block.timestamp, "ready time must be in the future");
        actions[index].ready = readyTime;
    }

    //---------- Proposal Flow ----------

    /**
     * @dev sets proposal title
     * @param newProposalTitle new proposal title
     */
    function setProposalTitle(string memory newProposalTitle) public onlyOwner onlyPreVote {
        proposalTitle = newProposalTitle;
    }

    /**
     * @dev configures proposal settings
     * @param isRevotable allows revoting on proposal if true
     */
    function configureProposal(bool isRevotable) public onlyOwner onlyPreVote {
        revotable = isRevotable;
    }

    /**
     * @dev pushes a new action to the end of the actions queue
     */
    function addAction(address target, uint256 value, string memory sig, bytes memory data) public onlyOwner onlyPreVote {
        //ready is set as zero when added, gets ready time set when loaded into action hopper
        Structs.Action memory act = Structs.Action(target, value, sig, data, 0);
        actions.push(act);
    }

    /**
     * @dev removes action at end of action queue
     */
    function removeAction() public onlyOwner onlyPreVote {
        actions.pop();
    }

    /**
     * @dev sets voting start and end time
     * @param newStartTime time voting will start
     * @param newEndTime time voting will end
     */
    function setVotingPeriod(uint256 newStartTime, uint256 newEndTime) public onlyOwner onlyPreVote {
        require(newStartTime >= block.timestamp, "start time must be in the future");
        require(newEndTime > newStartTime, "end time must be after start time");

        startTime = newStartTime;
        endTime = newEndTime;
    }

    /**
     * @dev casts a vote
     * @param tokenId id of token casting votes
     * @param vote number representing vote (0 = NO, 1 = YES, 2 = ABSTAIN)
     */
    function castVote(uint256 tokenId, uint8 vote) public {
        //validate
        //TODO: check dao membership?
        // require(IOGREDAO(daoAddress).getMemberStatus() == 1, "member is not registered");
        require(status == Enums.ProposalStatus.PROPOSED, "invalid state");
        require(IOGREDAO(daoAddress).isTokenOwner(tokenId, msg.sender), "caller not token owner");
        require(vote <= 2, "vote must be either NO (0), YES (1), or ABSTAIN (2)");
        require(block.timestamp >= startTime, "must be after start time");
        require(block.timestamp <= endTime, "must be before end time");

        //existing vote not found
        if (!votes[tokenId].voted) {
            voteCount += 1;
            voteTotals[vote] += 1;
        } else { //existing vote found
            require(revotable, "proposal is not revotable");
            voteTotals[votes[tokenId].direction] -= 1; //undo previous vote
            voteTotals[vote] += 1; //apply new vote
        }

        votes[tokenId].direction = vote;
        votes[tokenId].voted = true;

        emit VoteCast(msg.sender, tokenId, vote);
    }

}