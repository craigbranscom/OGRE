// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IOGREDAO.sol";
import {OGREDAOEnums, OGREProposalEnums} from "./libraries/Enums.sol";
import {IActionHopper} from "./interfaces/IActionHopper.sol";
import {IOGREProposal} from "./interfaces/IOGREProposal.sol";
import {IOGREDAO} from "./interfaces/IOGREDAO.sol";

/**
 * @title Open Governance Referendum Engine Proposal Contract
 * @author Craig Branscom
 */
contract OGREProposal is Ownable {

    //========== State ==========

    address public immutable daoAddress; //dao whose members are allowed to cast votes on proposal

    bool public revotable; //allows members to change their votes during voting period
    string public proposalURI; //metadata link to information about proposal
    
    OGREProposalEnums.ProposalStatus public status; //proposed, cancelled, failed, passed, executed (cancelled, failed, and executed are terminal states)
    uint256 public startTime; //start of vote period (unix timestamp)
    uint256 public endTime; //end of vote period (unix timestamp)
    uint256 public voteCount; //number of tokens that have cast a vote
    uint256[3] public voteTotals; //[0, 0, 0] == no, yes, abstain
    mapping(uint256 => IOGREProposal.Vote) public votes; //token id => vote struct
    IActionHopper.Action[] internal _passActions; //actions to load (in order) if proposal passes
    IActionHopper.Action[] internal _failActions; //actions to load (in order) if proposal fails

    //========== Events ==========

    /**
     * @notice Logs a change in proposal status.
     * @param previousStatus previous status of proposal
     * @param newStatus new status of proposal
     */
    event StatusUpdated(OGREProposalEnums.ProposalStatus previousStatus, OGREProposalEnums.ProposalStatus newStatus);

    /**
     * @notice Logs a vote.
     * @param voter address that cast the vote
     * @param tokenId id of nft token granting vote
     * @param vote direction of vote (0 = NO, 1 = YES, 2 = ABSTAIN)
     */
    event VoteCast(address voter, uint256 tokenId, OGREProposalEnums.VoteDirection vote);

    /**
     * @notice Logs a successful evaluation of proposal results.
     * @param quorumPassed true if proposal passed dao quorum threshold
     * @param supportPassed true if proposal passed dao support threshold
     * @param totalVotes final vote count on proposal
     */
    event ProposalEvaluated(bool quorumPassed, bool supportPassed, uint256 totalVotes, uint256 quorumVotesThreshold, uint256 supportVotesThreshold);

    //========== Errors ==========

    error InvalidAddress(string variableName, address value);
    error InvalidProposalStatus(OGREProposalEnums.ProposalStatus currentStatus, OGREProposalEnums.ProposalStatus requiredStatus);
    error InvalidMemberStatus(OGREDAOEnums.MemberStatus currentStatus, OGREDAOEnums.MemberStatus requiredStatus);
    error InvalidVoteDirection(OGREProposalEnums.VoteDirection vote);
    error InvalidTokenOwner(uint256 tokenId, address owner);
    error StartTimeInPast();
    error EndTimeBeforeStartTime();
    error InvalidVoteDuration();
    error NotRevotable();

    //========== Constructor ==========

    /**
     * @dev Creates proposal.
     * @param _params_ constructor params
     */
    constructor(
        IOGREProposal.ConstructorParams memory _params_
    ) Ownable(_params_.owner) {
        if (_params_.daoAddress == address(0x0)) revert InvalidAddress("daoAddress", _params_.daoAddress);

        daoAddress = _params_.daoAddress;
        revotable = _params_.revotable;
        proposalURI = _params_.proposalURI;

        emit StatusUpdated(OGREProposalEnums.ProposalStatus.PROPOSED, OGREProposalEnums.ProposalStatus.PROPOSED);
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

    /**
     * @dev Reverts if before vote end period
     */
    modifier onlyPostVote {
        require(block.timestamp > endTime, "must be post vote period");
        _;
    }

    //========== Configuration ==========

    /**
     * @dev Sets proposal metadata.
     * @param newProposalURI new proposal metadata uri
     */
    function setProposalURI(string memory newProposalURI) public onlyOwner onlyPreVote {
        proposalURI = newProposalURI;
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
     * @dev Sets actions for proposal. Ready time can be zero when added, gets ready time set when loaded into action hopper
     * @param passActionQueue true if actions are for pass queue, false if actions are for fail queue
     * @param newActions actions to load (in order)
     */
    function setActions(
        bool passActionQueue,
        IActionHopper.Action[] calldata newActions
    ) public onlyOwner onlyPreVote {
        passActionQueue ? delete _passActions : delete _failActions;
        if (newActions.length > 0) {
            if (passActionQueue) {
                for (uint256 i = 0; i < newActions.length; i++) {
                    _passActions.push(newActions[i]);
                }
            } else {
                for (uint256 i = 0; i < newActions.length; i++) {
                    _failActions.push(newActions[i]);
                }
            }
        }
    }

    /**
     * @dev Returns number of actions in proposal.
     * @return uint256 of actions in proposal
     */
    function getActionCount(bool passActionQueue) public view returns (uint256) {
        return passActionQueue ? _passActions.length : _failActions.length;
    }

    /**
     * @dev Returns action at index.
     * @param index index of action
     * @return Action action at index
     */
    function getActionByIndex(bool passActionQueue, uint256 index) public view returns (IActionHopper.Action memory) {
        return passActionQueue ? _passActions[index] : _failActions[index];
    }

    //========== Voting ==========

    /**
     * @dev casts a vote
     * @param tokenId id of token casting votes
     * @param vote number representing vote (0 = NO, 1 = YES, 2 = ABSTAIN)
     */
    function castVote(uint256 tokenId, OGREProposalEnums.VoteDirection vote) public {
        //validate
        if (status != OGREProposalEnums.ProposalStatus.PROPOSED) revert InvalidProposalStatus(status, OGREProposalEnums.ProposalStatus.PROPOSED);
        if (IOGREDAO(daoAddress).getMemberStatus(tokenId) != OGREDAOEnums.MemberStatus.REGISTERED) {
            revert InvalidMemberStatus(IOGREDAO(daoAddress).getMemberStatus(tokenId), OGREDAOEnums.MemberStatus.REGISTERED);
        }
        address nftAddress = IOGREDAO(daoAddress).nftAddress();
        if (IERC721(nftAddress).ownerOf(tokenId) != msg.sender) revert InvalidTokenOwner(tokenId, msg.sender);
        if (vote > OGREProposalEnums.VoteDirection(2)) revert InvalidVoteDirection(vote);
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
    function getVote(uint256 tokenId) public view returns (IOGREProposal.Vote memory) {
        return votes[tokenId];
    }

    //========== Proposal Lifecycle ==========

    /**
     * @dev Cancels proposal.
     */
    function cancelProposal() public onlyOwner {
        if (status != OGREProposalEnums.ProposalStatus.PROPOSED) {
            revert InvalidProposalStatus(status, OGREProposalEnums.ProposalStatus.PROPOSED);
        }
        _updateStatus(OGREProposalEnums.ProposalStatus.CANCELLED);
    }

    /**
     * @dev Sets action ready time.
     * @param index index of action
     * @param readyTime ready time of action
     */
    function setActionReady(bool passActionQueue, uint256 index, uint256 readyTime) external onlyDAO {
        // require(getActionCount() > 0, "no actions to update");
        // require(index <= getActionCount() - 1, "no action at index");
        // require(readyTime > block.timestamp, "ready time must be in the future");
        if (passActionQueue) {
            _passActions[index].ready = readyTime;
        } else {
            _failActions[index].ready = readyTime;
        }
    }

    //========== Internal ==========

    /**
     * @dev Updates proposal status.
     * @param newStatus new status of proposal
     */
    function _updateStatus(OGREProposalEnums.ProposalStatus newStatus) internal {
        emit StatusUpdated(status, newStatus);
        status = newStatus;
    }

}