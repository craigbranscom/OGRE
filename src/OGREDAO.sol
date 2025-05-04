// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IOGREProposalFactory.sol";
import "./interfaces/IOGREProposal.sol";
import "./abstract/ActionHopper.sol";

import {Constants} from "./libraries/Constants.sol";
import {OGREDAOEnums} from "./libraries/Enums.sol";
import {IOGREDAO} from "./interfaces/IOGREDAO.sol";

/**
 * @title Open Governance Referendum Engine DAO Contract
 * @author Craig Branscom
 * @notice This contract represents a DAO that uses an ERC721 contract to track membership. 
 *         It is designed to be used in conjunction with the OGREProposalFactory contract to create and manage proposals.
 *         The DAO is responsible for managing the membership of the DAO, including inviting members, registering members, 
 *         and unregistering members. It also manages the creation and evaluation of proposals.
 *         DAO members may create proposals that may include actions to be executed if the proposal is approved.
 */
contract OGREDAO is ActionHopper {

    //========== State ==========

    uint32 public constant PERCENTAGE_RESOLUTION = 10000; //10000 = 100.00%

    address public immutable parentDAO; //address of parent dao. zero address indicates top level dao
    address public immutable proposalFactoryAddress; //address of proposal factory used by dao
    address public immutable nftAddress; //ERC721 contract tracking member voting eligibility

    uint256 public quorumThreshold; //minimum percentage of total members (nft tokens) participation needed to recognize a proposal (e.g. 555 = 5.55%)
    uint256 public supportThreshold; //minimum percentage of YES votes required to pass proposal (e.g. 6700 = 67.00%)
    uint256 public minVoteDuration; //min length of time (in seconds) that a proposal must be open for a vote

    uint256 public memberCount; //number of invited nfts from set that have been registered to the dao
    mapping(uint256 => OGREDAOEnums.MemberStatus) private _members; //token id => member status
    mapping(uint256 => bool) public memberAllowlist; //token id => isAllowed
    bool public allowListEnabled; //if true, only members in the allowlist can register

    uint256 public proposalCount; //number of proposals that have been created by the dao
    mapping(uint256 => address) public proposals; //proposal[i] => proposal address
    mapping(address => uint256) private _proposals; //proposal[i] => proposal id
    uint256 public proposalCost; //amount required to make a proposal (in wei)
    address public proposalCostToken; //zero address indicates native token

    //========== Events ==========

    /**
     * @notice Logs a successful dao creation
     * @param nftAddress address of nft contract linked to dao
     * @param proposalFactoryAddress address of proposal factory used by dao
     */
    event DAOCreated(address parentDAO, address nftAddress, address proposalFactoryAddress);

    /**
     * @notice Logs a successful member registration
     * @param tokenId id of nft token being registered to dao
     * @param registeredBy address registering token
     */
    event MemberRegistered(uint256 indexed tokenId, address indexed registeredBy);

    /**
     * @notice Logs a proposal creation
     * @param proposal address of proposal contract
     * @param proposalId unique proposal id assigned by dao
     * @param createdBy proposal creator
     */
    event ProposalCreated(address proposal, uint256 proposalId, address indexed createdBy);

    /**
     * @notice Logs a successful proposal evaluation
     * @param quorumPassed true if proposal passed dao quorum threshold
     * @param supportPassed true if proposal passed dao support threshold
     * @param totalVotes final vote count on proposal
     */
    event ProposalEvaluated(bool indexed quorumPassed, bool indexed supportPassed, uint256 totalVotes, uint256 quorumVotesThreshold, uint256 supportVotesThreshold);

    /**
     * @notice Logs successful execution of all proposal actions
     * @param proposal address of proposal that was executed
     */
    event ProposalExecuted(address proposal);

    //========== Errors ==========

    error InvalidAddress(string variableName, address value);
    error InvalidSender(address sender, address required);
    error InvalidMemberStatus();
    error InvalidThreshold(uint256 threshold);
    error InvalidDelay();
    error TokenAlreadyRegistered();
    error TokenAlreadyUnregistered();
    error InsufficientPayment(uint256 provided, uint256 required);
    error PaymentFailed(address token, uint256 provided, uint256 required);
    error ProposalNotRecognized();
    error InvalidProposalState();
    error VotePeriodNotEnded();
    error NoActionsToExecute();

    //========== Constructor ==========

    /**
     * @notice Creates a new OGREDAO
     * @param _params_ OGREDAO constructor parameters
     */
    constructor(
        IOGREDAO.ConstructorParams memory _params_
    ) ActionHopper(_params_.delay) {
        // validate
        if (_params_.parentDAO != address(0x0)) {
            if (msg.sender != _params_.parentDAO) revert InvalidSender(msg.sender, _params_.parentDAO);
        }
        if (_params_.nftAddress == address(0x0)) revert InvalidAddress("nftAddress", _params_.nftAddress);
        if (_params_.proposalFactoryAddress == address(0x0)) revert InvalidAddress("proposalFactoryAddress", _params_.proposalFactoryAddress);

        // initialize
        parentDAO = _params_.parentDAO;
        nftAddress = _params_.nftAddress;
        proposalFactoryAddress = _params_.proposalFactoryAddress;
        proposalCost = _params_.proposalCost;
        proposalCostToken = _params_.proposalCostToken;
        quorumThreshold = _params_.quorumThreshold;
        supportThreshold = _params_.supportThreshold;
        minVoteDuration = _params_.minVoteDuration;

        //enable allowlist if provided
        if (_params_.allowList.length > 0) {
            allowListEnabled = true;
            for (uint256 i = 0; i < _params_.allowList.length; i++) {
                memberAllowlist[_params_.allowList[i]] = true;
            }
        }

        //register initial members if provided
        if (_params_.initialMembers.length > 0) {
            for (uint256 i = 0; i < _params_.initialMembers.length; i++) {
                _registerMember(_params_.initialMembers[i]);
            }
        }

        emit DAOCreated(_params_.parentDAO, _params_.nftAddress, _params_.proposalFactoryAddress);
    }

    //========== Configuration ==========

    /**
     * @dev Sets new quorum threshold for dao. 
     * @param newQuorumThreshold quorum percentage (e.g. 555 = 5.55%)
     */
    function setQuorumThreshold(uint256 newQuorumThreshold) public {
        if (newQuorumThreshold > PERCENTAGE_RESOLUTION) revert InvalidThreshold(newQuorumThreshold);
        if (newQuorumThreshold == 0) revert InvalidThreshold(newQuorumThreshold);

        quorumThreshold = newQuorumThreshold;
    }

    /**
     * @dev Sets new support threshold for dao
     * @param newSupportThreshold support percentage (e.g. 555 = 5.55%)
     */
    function setSupportThreshold(uint256 newSupportThreshold) public {
        if (newSupportThreshold > PERCENTAGE_RESOLUTION) revert InvalidThreshold(newSupportThreshold);
        if (newSupportThreshold == 0) revert InvalidThreshold(newSupportThreshold);

        supportThreshold = newSupportThreshold;
    }

    /**
     * @dev Sets new min vote duration for dao
     * @param newMinVoteDuration min time in seconds
     */
    function setMinVoteDuration(uint256 newMinVoteDuration) public {
        minVoteDuration = newMinVoteDuration;
    }

    /**
     * @dev Sets new proposal cost for dao
     * @param newProposalCost new proposal cost in wei
     */
    function setProposalCost(uint256 newProposalCost) public {
        proposalCost = newProposalCost;
    }

    /**
     * @dev Sets a new delay for action hopper
     * @param newDelay new delay value (in seconds)
     */
    function setActionDelay(uint256 newDelay) public {
        if (newDelay == 0) revert InvalidDelay();
        _setDelay(newDelay);
    }

    //========== Membership ==========

    /**
     * @dev Registers a member to the dao
     * @param tokenId id of nft token being registered to dao
     */
    function registerMember(uint256 tokenId) public {
        if (IERC721(nftAddress).ownerOf(tokenId) != msg.sender) revert InvalidSender(msg.sender, IERC721(nftAddress).ownerOf(tokenId));
        if (_members[tokenId] == OGREDAOEnums.MemberStatus.REGISTERED) revert TokenAlreadyRegistered();

        _registerMember(tokenId);
    }

    /**
     * @dev Returns the status of a member
     * @param tokenId id of nft token to check
     * @return status status of member
     */
    function getMemberStatus(uint256 tokenId) public view returns (OGREDAOEnums.MemberStatus) {
        return _members[tokenId];
    }

    //========== Proposals ==========

    /**
     * @dev Drafts a new proposal
     */
    function draftProposal(string memory proposalURI) public payable returns (address) {
        //validate
        if (proposalCostToken == address(0x0)) {
            if (msg.value != proposalCost) revert InsufficientPayment(msg.value, proposalCost);
        } else {
            /// @dev requires approval from token owner
            bool success = IERC20(proposalCostToken).transferFrom(msg.sender, address(this), proposalCost);
            if (!success) revert PaymentFailed(proposalCostToken, msg.value, proposalCost);
        }

        return _draftProposal(proposalURI);
    }

    /**
     * @dev Evaluate a proposal using quorum and support thresholds from this dao. Proposal must
     *      have been created through this dao. Updates proposal contract state to either PASSED
     *      or FAILED. Emits a ProposalEvaluated event.
     * @param proposal address of proposal contract to evaluate
     * @return bool true if proposal passed, false if failed
     */
    function evaluateProposal(address proposal) public returns (bool) {
        if (!isProposal(proposal)) revert ProposalNotRecognized();
        if (IOGREProposal(proposal).status() != OGREProposalEnums.ProposalStatus.PROPOSED) revert InvalidProposalState();
        if (IOGREProposal(proposal).startTime() == 0) revert InvalidProposalState();
        if (block.timestamp <= IOGREProposal(proposal).endTime()) revert VotePeriodNotEnded();

        uint256 noVotes = IOGREProposal(proposal).voteTotals(0);
        uint256 yesVotes = IOGREProposal(proposal).voteTotals(1);
        uint256 abstainVotes = IOGREProposal(proposal).voteTotals(2);
        uint256 totalVotes = noVotes + yesVotes + abstainVotes;

        uint256 quorumVotesThreshold = (memberCount * quorumThreshold) / PERCENTAGE_RESOLUTION;
        uint256 supportVotesThreshold = (memberCount * supportThreshold) / PERCENTAGE_RESOLUTION;

        bool supportPassed = false;
        bool quorumPassed = false;

        //check if support passed
        if (yesVotes > supportVotesThreshold) {
            supportPassed = true;
        }

        //check if quorum passed
        if (totalVotes > quorumVotesThreshold) {
            quorumPassed = true;
        }

        if (supportPassed && quorumPassed) {
            //set proposal status to passed
            IOGREProposal(proposal).updateStatus(3);

            //load actions into hopper
            uint256 actionCount = IOGREProposal(proposal).getActionCount();
            for (uint8 i = 0; i < actionCount; i++) {
                IActionHopper.Action memory act = IOGREProposal(proposal).getAction(i);
                act.ready = _loadAction(act.target, act.value, act.sig, act.data);
                IOGREProposal(proposal).setActionReady(i, act.ready);
            }
        } else {
            //set proposal status to failed
            IOGREProposal(proposal).updateStatus(2);
        }

        emit ProposalEvaluated(quorumPassed, supportPassed, totalVotes, quorumVotesThreshold, supportVotesThreshold);

        return quorumPassed && supportPassed;
    }

    /**
     * @dev Executes readied actions
     */
    function executeProposal(address proposal) public {
        if (!isProposal(proposal)) revert ProposalNotRecognized();
        if (IOGREProposal(proposal).status() != OGREProposalEnums.ProposalStatus.PASSED) revert InvalidProposalState();
        if (IOGREProposal(proposal).getActionCount() == 0) revert NoActionsToExecute();

        //set proposal status to executed
        IOGREProposal(proposal).updateStatus(4);

        //execute readied actions
        uint256 actionCount = IOGREProposal(proposal).getActionCount();
        for (uint8 i = 0; i < actionCount; i++) {
            IActionHopper.Action memory act = IOGREProposal(proposal).getAction(i);
            _executeAction(act.target, act.value, act.sig, act.data, act.ready);
        }

        emit ProposalExecuted(proposal);
    }

    /**
     * @dev Checks if address is a proposal contract created by dao.
     * @param proposal address to check
     * @return bool true if proposal is created by dao, false otherwise
     */
    function isProposal(address proposal) public view returns (bool) {
        return _proposals[proposal] > 0;
    }

    //========== Internal ==========

    function _registerMember(uint256 tokenId) internal {
        _members[tokenId] = OGREDAOEnums.MemberStatus.REGISTERED;
        memberCount += 1;

        emit MemberRegistered(tokenId, msg.sender);
    }

    function _draftProposal(string memory proposalURI) internal returns (address) {
        //call proposal factory to create new proposal
        address prop = IOGREProposalFactory(proposalFactoryAddress).produceOGREProposal(proposalURI, address(this), msg.sender);

        //update state
        proposalCount += 1;
        _proposals[prop] = proposalCount;
        proposals[proposalCount] = prop;

        emit ProposalCreated(prop, proposalCount, msg.sender);

        return prop;
    }

    //========== Receive ==========

    receive() external payable {}

    fallback() external payable {}
}