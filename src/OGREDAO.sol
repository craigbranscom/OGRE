// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IOGREProposalFactory.sol";
import "./interfaces/IOGREProposal.sol";
import "./abstract/ActionHopper.sol";

import {Constants} from "./libraries/Constants.sol";
import {Enums} from "./libraries/Enums.sol";
import {Structs} from "./libraries/Structs.sol";

//TODO: index event params?
//TODO: track proposal status?
//TODO: forward tokens sent to dao to treasury?
//TODO: draftAndLaunchProposal? scheduleProposal()?
//TODO: add supportsInterface()? see ERC165

/**
 * @title Open Governance Referendum Engine DAO Contract
 * @author Craig Branscom
 * @notice This contract represents a DAO that uses an ERC721 contract to track membership. 
 *         It is designed to be used in conjunction with the OGREProposalFactory contract to create and manage proposals.
 *         The DAO is responsible for managing the membership of the DAO, including inviting members, registering members, 
 *         and unregistering members. It also manages the creation and evaluation of proposals.
 *         DAO members may create proposals that may include actions to be executed if the proposal is approved.
 */
contract OGREDAO is AccessControl, ActionHopper {

    //========== State ==========

    address public immutable proposalFactoryAddress; //address of proposal factory used by dao
    address public immutable nftAddress; //ERC721 contract tracking member voting rights

    string public daoName; //name of the dao
    string public daoMetadata; //metadata link for the dao

    uint256 public quorumThreshold; //minimum percentage of total members (nft tokens) participation needed to recognize a proposal (e.g. 555 = 5.55%)
    uint256 public supportThreshold; //minimum percentage of YES votes required to pass proposal (e.g. 6700 = 67.00%)
    uint256 public minVotePeriod; //min length of time (in seconds) that a proposal must be open for a vote

    uint256 public memberCount; //number of invited nfts from set that have been registered to the dao. this number is reduced if token is unregistered or banned
    mapping(uint256 => Enums.MemberStatus) private _members; //token id => member status

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
     * @param admin address set with initial admin role
     */
    event DAOCreated(address nftAddress, address indexed proposalFactoryAddress, address indexed admin);

    /**
     * @notice Logs a successful member invited
     * @param daoAddress address of dao where member was invited
     * @param nftAddress address of nft contract linked to dao
     * @param tokenId id of nft token being registered to dao
     */
    event MemberInvited(address daoAddress, address indexed nftAddress, uint256 indexed tokenId);

    /**
     * @notice Logs a successful member registration
     * @param daoAddress address of dao where member was registered
     * @param nftAddress address of nft contract linked to dao
     * @param tokenId id of nft token being registered to dao
     * @param memberAddress address registering token
     */
    event MemberRegistered(address daoAddress, address indexed nftAddress, uint256 indexed tokenId, address indexed memberAddress);

    /**
     * @notice Logs a successful member unregistration
     * @param daoAddress address of dao where member was unregistered
     * @param nftAddress address of nft contract linked to dao
     * @param tokenId id of nft token being unregistered
     * @param memberAddress address unregistering token
     */
    event MemberUnregistered(address daoAddress, address nftAddress, uint256 tokenId, address memberAddress);

    /**
     * @notice Logs a proposal creation
     * @param daoAddress address of dao
     * @param proposal address of proposal contract
     * @param proposalId unique proposal id assigned by dao
     * @param creator address of proposal creator
     */
    event ProposalCreated(address daoAddress, address proposal, uint256 proposalId, address creator);

    /**
     * @notice Logs a successful proposal evaluation
     * @param quorumPassed true if proposal passed dao quorum threshold
     * @param supportPassed true if proposal passed dao support threshold
     * @param totalVotes final vote count on proposal
     */
    event ProposalEvaluated(bool quorumPassed, bool supportPassed, uint256 totalVotes, uint256 quorumVotesThreshold, uint256 supportVotesThreshold);

    /**
     * @notice Logs successful execution of all proposal actions
     * @param proposal address of proposal that was executed
     */
    event ProposalExecuted(address proposal);

    //========== Errors ==========

    error ZeroAddressNotAllowed();
    error InvalidThreshold(uint256 threshold);
    error InvalidDelay();
    error TokenAlreadyRegistered();
    error TokenAlreadyUnregistered();
    error NotTokenOwner();
    error InsufficientPayment();
    error NotProposal();
    error InvalidProposalState();
    error VotePeriodNotEnded();
    error NoActionsToExecute();

    //========== Constructor ==========

    /**
     * @param daoName_ name of the dao
     * @param daoMetadata_ metadata link for the dao
     * @param nftAddress_ address of ERC721 contract representing voting rights
     * @param proposalFactoryAddress_ address of OGREProposalFactory contract
     * @param proposalCost_ required cost to draft a proposal (in wei)
     * @param admin_ address that will be assigned the DAO_ADMIN role
     * @param delay_ amount of time that must elapse before a loaded action can be executed (in seconds)
     */
    constructor(
        string memory daoName_, 
        string memory daoMetadata_, 
        address nftAddress_, 
        address proposalFactoryAddress_, 
        uint256 proposalCost_, 
        address admin_, 
        uint256 delay_
    ) ActionHopper(delay_) {
        if (nftAddress_ == address(0x0)) revert ZeroAddressNotAllowed();
        if (admin_ == address(0x0)) revert ZeroAddressNotAllowed();

        daoName = daoName_;
        daoMetadata = daoMetadata_;
        nftAddress = nftAddress_;
        proposalFactoryAddress = proposalFactoryAddress_;
        proposalCost = proposalCost_;

        _grantRole(Constants.DAO_ADMIN, admin_);
        _grantRole(Constants.DAO_INVITE, admin_);
        _setRoleAdmin(Constants.DAO_INVITE, Constants.DAO_ADMIN);

        emit DAOCreated(nftAddress_, proposalFactoryAddress_, admin_);
    }

    //========== Configuration ==========

    /**
     * @dev Sets new dao name
     * @param newDAOName new dao name
     */
    function setDAOName(string memory newDAOName) public {
        daoName = newDAOName;
    }

    /**
     * @dev Sets new dao metadata
     * @param newDAOMetadata new dao metadata
     */
    function setDAOMetadata(string memory newDAOMetadata) public {
        daoMetadata = newDAOMetadata;
    }

    /**
     * @dev Sets new quorum threshold for dao. 
     * @param newQuorumThreshold quorum percentage (e.g. 555 = 5.55%)
     */
    function setQuorumThreshold(uint256 newQuorumThreshold) public {
        if (newQuorumThreshold > 10000) revert InvalidThreshold(newQuorumThreshold);
        if (newQuorumThreshold == 0) revert InvalidThreshold(newQuorumThreshold);

        quorumThreshold = newQuorumThreshold;
    }

    /**
     * @dev Sets new support threshold for dao
     * @param newSupportThreshold support percentage (e.g. 555 = 5.55%)
     */
    function setSupportThreshold(uint256 newSupportThreshold) public {
        if (newSupportThreshold > 10000) revert InvalidThreshold(newSupportThreshold);
        if (newSupportThreshold == 0) revert InvalidThreshold(newSupportThreshold);

        supportThreshold = newSupportThreshold;
    }

    /**
     * @dev Sets new min vote period for dao
     * @param newMinVotePeriod min time in seconds
     */
    function setMinVotePeriod(uint256 newMinVotePeriod) public {
        minVotePeriod = newMinVotePeriod;
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

    function registerMember(uint256 tokenId) public {
        if (IERC721(nftAddress).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (_members[tokenId] == Enums.MemberStatus.REGISTERED) revert TokenAlreadyRegistered();

        _members[tokenId] = Enums.MemberStatus.REGISTERED;
        memberCount += 1;

        emit MemberRegistered(address(this), nftAddress, tokenId, msg.sender);
    }

    function unregisterMember(uint256 tokenId) public {
        if (IERC721(nftAddress).ownerOf(tokenId) != msg.sender) revert NotTokenOwner();
        if (_members[tokenId] == Enums.MemberStatus.UNREGISTERED) revert TokenAlreadyUnregistered();

        _members[tokenId] = Enums.MemberStatus.UNREGISTERED;
        memberCount -= 1;

        emit MemberUnregistered(address(this), nftAddress, tokenId, msg.sender);
    }

    function getMemberStatus(uint256 tokenId) public view returns (Enums.MemberStatus) {
        return _members[tokenId];
    }

    //========== Proposals ==========

    /**
     * @dev Returns true if address is a proposal contract created by dao.
     * @param proposal address to check
     */
    function isProposal(address proposal) public view returns (bool) {
        return _proposals[proposal] > 0;
    }

    /**
     * @dev Crafts a new proposal
     */
    function draftProposal(string memory proposalTitle) public payable returns (address) {
        if (msg.value != proposalCost) revert InsufficientPayment();

        //call proposal factory to create new proposal
        address prop = IOGREProposalFactory(proposalFactoryAddress).produceOGREProposal(proposalTitle, address(this), msg.sender);

        //update state
        proposalCount += 1;
        _proposals[prop] = proposalCount;
        proposals[proposalCount] = prop;

        emit ProposalCreated(address(this), prop, proposalCount, msg.sender);

        return prop;
    }

    /**
     * @dev Evaluate a proposal using quorum and support thresholds from this dao. Proposal must
     *      have been created through this dao. Updates proposal contract state to either PASSED
     *      or FAILED. Emits a ProposalEvaluated event.
     * @param proposal address of proposal contract to evaluate
     * @return bool true if proposal passed, false if failed
     */
    function evaluateProposal(address proposal) public returns (bool) {
        if (!isProposal(proposal)) revert NotProposal();
        if (IOGREProposal(proposal).status() != Enums.ProposalStatus.PROPOSED) revert InvalidProposalState();
        if (IOGREProposal(proposal).startTime() == 0) revert InvalidProposalState();
        if (block.timestamp <= IOGREProposal(proposal).endTime()) revert VotePeriodNotEnded();

        uint256 noVotes = IOGREProposal(proposal).voteTotals(0);
        uint256 yesVotes = IOGREProposal(proposal).voteTotals(1);
        uint256 abstainVotes = IOGREProposal(proposal).voteTotals(2);
        uint256 totalVotes = noVotes + yesVotes + abstainVotes;

        uint256 quorumVotesThreshold = (memberCount * quorumThreshold) / 10000;
        uint256 supportVotesThreshold = (memberCount * supportThreshold) / 10000;

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
                Structs.Action memory act = IOGREProposal(proposal).getAction(i);
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
        if (!isProposal(proposal)) revert NotProposal();
        if (IOGREProposal(proposal).status() != Enums.ProposalStatus.PASSED) revert InvalidProposalState();
        if (IOGREProposal(proposal).getActionCount() == 0) revert NoActionsToExecute();

        //set proposal status to executed
        IOGREProposal(proposal).updateStatus(4);

        //execute readied actions
        uint256 actionCount = IOGREProposal(proposal).getActionCount();
        for (uint8 i = 0; i < actionCount; i++) {
            Structs.Action memory act = IOGREProposal(proposal).getAction(i);
            _executeAction(act.target, act.value, act.sig, act.data, act.ready);
        }

        emit ProposalExecuted(proposal);
    }

    //========== Receive ==========

    receive() external payable {}

    fallback() external payable {}
}