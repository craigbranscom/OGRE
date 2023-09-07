// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IOGREProposalFactory.sol";
import "./interfaces/IOGREProposal.sol";
import "./abstract/ActionHopper.sol";
import "./abstract/ERC721Receivable.sol";

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
 */
contract OGREDAO is AccessControl, ActionHopper, ERC721Receivable {

    address public immutable proposalFactoryAddress;
    address public immutable nftAddress; //ERC721 contract tracking member voting rights

    string public daoName;
    string public daoMetadata;

    uint256 public quorumThreshold; //minimum percentage of total members (nft tokens) participation needed to recognize a proposal (e.g. 555 = 5.55%)
    uint256 public supportThreshold; //minimum percentage of YES votes required to pass proposal (e.g. 6700 = 67.00%)
    uint256 public minVotePeriod; //min length of time (in seconds) that a proposal must be open for a vote

    // Enums.AccessType daoAccessType;
    // uint256 public inviteCount; //number of outstanding invites. when an invite is accepted this number is reduced
    uint256 public memberCount; //number of invited nfts from set that have been registered to the dao. this number is reduced if token is unregistered or banned
    mapping(uint256 => Enums.MemberStatus) private _members; //token id => member status

    uint256 public proposalCount; //number of proposals that have been created by the dao
    mapping(uint256 => address) public proposals; //proposal[i] => proposal address
    mapping(address => uint256) private _proposals; //proposal[i] => proposal id
    uint256 public proposalCost; //amount required to make a proposal (in wei)
    // address public proposalCostToken; //zero address indicates native token

    /**
     * @notice logs a successful dao creation
     * @param nftAddress address of nft contract linked to dao
     * @param proposalFactoryAddress address of proposal factory used by dao
     * @param admin address set with initial admin role
     */
    event DAOCreated(address nftAddress, address proposalFactoryAddress, address admin);

    /**
     * @notice logs a successful member invited
     * @param daoAddress address of dao where member was invited
     * @param nftAddress address of nft contract linked to dao
     * @param tokenId id of nft token being registered to dao
     */
    event MemberInvited(address daoAddress, address nftAddress, uint256 tokenId);

    /**
     * @notice logs a successful member registration
     * @param daoAddress address of dao where member was registered
     * @param nftAddress address of nft contract linked to dao
     * @param tokenId id of nft token being registered to dao
     * @param memberAddress address registering token
     */
    event MemberRegistered(address daoAddress, address nftAddress, uint256 tokenId, address memberAddress);

    /**
     * @notice logs a successful member unregistration
     * @param daoAddress address of dao where member was unregistered
     * @param nftAddress address of nft contract linked to dao
     * @param tokenId id of nft token being unregistered
     * @param memberAddress address unregistering token
     */
    event MemberUnregistered(address daoAddress, address nftAddress, uint256 tokenId, address memberAddress);

    /**
     * @notice logs a proposal creation
     * @param daoAddress address of dao
     * @param proposal address of proposal contract
     * @param proposalId unique proposal id assigned by dao
     * @param creator address of proposal creator
     */
    event ProposalCreated(address daoAddress, address proposal, uint256 proposalId, address creator);

    /**
     * @notice logs a successful proposal evaluation
     * @param quorumPassed true if proposal passed dao quorum threshold
     * @param supportPassed true if proposal passed dao support threshold
     * @param totalVotes final vote count on proposal
     */
    event ProposalEvaluated(bool quorumPassed, bool supportPassed, uint256 totalVotes, uint256 quorumVotesThreshold, uint256 supportVotesThreshold);

    /**
     * @notice logs successful execution of all proposal actions
     * @param proposal address of proposal that was executed
     */
    event ProposalExecuted(address proposal);

    /**
     * @param daoName_ name of the dao
     * @param daoMetadata_ metadata link for the dao
     * @param nftAddress_ address of ERC721 contract representing voting rights
     * @param proposalFactoryAddress_ address of OGREProposalFactory contract
     * @param proposalCost_ required cost to draft a proposal (in wei)
     * @param admin_ address that will be assigned the DAO_ADMIN role
     * @param delay_ amount of time that must elapse before a loaded action can be executed (in seconds)
     */
    constructor(string memory daoName_, string memory daoMetadata_, address nftAddress_, 
    address proposalFactoryAddress_, uint256 proposalCost_, address admin_, uint256 delay_) ActionHopper(delay_) {
        require(nftAddress_ != address(0x0), "nft address cannot be zero address");
        require(admin_ != address(0x0), "admin role cannot be zero address");

        daoName = daoName_;
        daoMetadata = daoMetadata_;
        nftAddress = nftAddress_;
        proposalFactoryAddress = proposalFactoryAddress_;
        proposalCost = proposalCost_;

        _setupRole(Constants.DAO_ADMIN, admin_);
        _setupRole(Constants.DAO_INVITE, admin_);
        _setRoleAdmin(Constants.DAO_INVITE, Constants.DAO_ADMIN);

        emit DAOCreated(nftAddress_, proposalFactoryAddress_, admin_);
    }

    //---------- Config ----------

    /**
     * @dev sets new dao name
     * @param newDAOName new dao name
     */
    function setDAOName(string memory newDAOName) public {
        daoName = newDAOName;
    }

    /**
     * @dev sets new dao metadata
     * @param newDAOMetadata new dao metadata
     */
    function setDAOMetadata(string memory newDAOMetadata) public {
        daoMetadata = newDAOMetadata;
    }

    /**
     * @dev sets new quorum threshold for dao. 
     * @param newQuorumThreshold quorum percentage (e.g. 555 = 5.55%)
     */
    function setQuorumThreshold(uint256 newQuorumThreshold) public {
        require(newQuorumThreshold <= 10000, "threshold cannot be above 10000 (100%)");
        require(newQuorumThreshold > 0, "threshold must be above zero");

        quorumThreshold = newQuorumThreshold;
    }

    /**
     * @dev sets new support threshold for dao
     * @param newSupportThreshold support percentage (e.g. 555 = 5.55%)
     */
    function setSupportThreshold(uint256 newSupportThreshold) public {
        require(newSupportThreshold <= 10000, "threshold cannot be above 10000 (100%)");
        require(newSupportThreshold > 0, "threshold must be above zero");

        supportThreshold = newSupportThreshold;
    }

    /**
     * @dev sets new min vote period for dao
     * @param newMinVotePeriod min time in seconds
     */
    function setMinVotePeriod(uint256 newMinVotePeriod) public {
        minVotePeriod = newMinVotePeriod;
    }

    /**
     * @dev sets a new delay for action hopper
     * @param newDelay new delay value (in seconds)
     */
    function setDelay(uint256 newDelay) public {
        require(newDelay > 0, "delay must be greater than zero");
        _setDelay(newDelay);
    }

    //---------- Members ----------

    function inviteMember(uint256 tokenId) public onlyRole(Constants.DAO_INVITE) {
        require(_members[tokenId] == Enums.MemberStatus.UNREGISTERED, "token must be unregistered to invite");

        _members[tokenId] = Enums.MemberStatus.INVITED;

        emit MemberInvited(address(this), nftAddress, tokenId);
    } 

    function registerMember(uint256 tokenId) public {
        require(IERC721(nftAddress).ownerOf(tokenId) == msg.sender, "sender must be token owner to register");
        require(_members[tokenId] != Enums.MemberStatus.REGISTERED, "token is already registered");

        _members[tokenId] = Enums.MemberStatus.REGISTERED;
        memberCount += 1;

        emit MemberRegistered(address(this), nftAddress, tokenId, msg.sender);
    }

    function unregisterMember(uint256 tokenId) public {
        require(IERC721(nftAddress).ownerOf(tokenId) == msg.sender, "sender must be token owner to unregister");
        require(_members[tokenId] != Enums.MemberStatus.UNREGISTERED, "token is already unregistered");

        _members[tokenId] = Enums.MemberStatus.UNREGISTERED;
        memberCount -= 1;

        emit MemberUnregistered(address(this), nftAddress, tokenId, msg.sender);
    }

    function getMemberStatus(uint256 tokenId) public view returns (Enums.MemberStatus) {
        return _members[tokenId];
    }

    function isTokenOwner(uint256 tokenId, address member) public view returns (bool) {
        return IERC721(nftAddress).ownerOf(tokenId) == member;
    }

    //---------- Proposals ----------

    /**
     * @dev returns true if address is a proposal contract created by dao.
     * @param proposal address to check
     */
    function isProposal(address proposal) public view returns (bool) {
        return _proposals[proposal] > 0;
    }

    /**
     * @dev craft a new proposal
     */
    function draftProposal(string memory proposalTitle) public payable returns (address) {
        require(msg.value == proposalCost, "insufficient payment for draft proposal");

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
        require(isProposal(proposal), "address is not a proposal created by this dao");
        require(IOGREProposal(proposal).status() == Enums.ProposalStatus.PROPOSED, "invalid proposal state");
        require(IOGREProposal(proposal).startTime() != 0, "vote period has not been set");
        require(block.timestamp > IOGREProposal(proposal).endTime(), "cannot evaluate before vote period has ended");

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
     * @dev executes readied actions
     */
    function executeProposal(address proposal) public {
        require(isProposal(proposal), "address is not a proposal created by this dao");
        require(IOGREProposal(proposal).status() == Enums.ProposalStatus.PASSED, "invalid proposal state");
        require(IOGREProposal(proposal).getActionCount() > 0, "no actions to execute");

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

    receive() external payable {}

    fallback() external payable {}
}