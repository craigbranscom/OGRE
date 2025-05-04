// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../src/OGREDAO.sol";
import "../src/samples/SampleERC721.sol";
import "../src/OGREProposal.sol";
import "../src/factories/OGREProposalFactory.sol";
import "../src/samples/SampleERC20.sol";
import {IOGREDAO} from "../src/interfaces/IOGREDAO.sol";

contract OGREDAOTest is Test {
    // Accounts
    address user0;
    address user1;
    address user2;

    // ERC721
    string name = "Test NFTs";
    string symbol = "TEST";
    uint256 maxSupply = 10;
    address owner;

    // OGRE DAO
    string daoName = "Test DAO";
    string daoMetadata = "https://some-api-endpoint.com/";
    uint256 delay = 10; // in seconds
    uint256 quorumThresh = 5000; // 50%
    uint256 supportThresh = 6000; // 60%
    uint256 minVotePeriod = 300; // 5 mins
    uint256 proposalCost = 0; // free proposals
    address proposalCostToken = address(0x0); //native token
    uint256[] allowList;
    uint256[] initialMembers;

    // OGRE Proposal
    string proposalURI = "https://some-api-endpoint.com/";
    uint256 startTime;
    uint256 endTime;

    OGREProposalFactory proposalFactoryContract;
    SampleERC721 nftContract;
    OGREDAO daoContract;
    OGREProposal proposalContract;
    SampleERC20 erc20Contract;

    function setUp() public {
        // Get signers
        user0 = makeAddr("user0");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        proposalFactoryContract = new OGREProposalFactory();
        nftContract = new SampleERC721(name, symbol);
        erc20Contract = new SampleERC20(name, symbol, user0);

        // Mint NFTs to user0
        for (uint256 i = 0; i < 10; i++) {
            nftContract.mint(user0, i);
        }
        
        // Mint ERC20s to user0
        vm.prank(user0);
        erc20Contract.mint(user0, 100);
    }

    modifier setupDAO(uint32 configId) {
        if (configId == 0) {
            // Deploy DAO
            daoContract = new OGREDAO(IOGREDAO.ConstructorParams({
                parentDAO: address(0x0),
                nftAddress: address(nftContract),
                proposalFactoryAddress: address(proposalFactoryContract),
                proposalCost: proposalCost,
                proposalCostToken: address(0x0),
                quorumThreshold: quorumThresh,
                supportThreshold: supportThresh,
                minVoteDuration: minVotePeriod,
                delay: delay,
                allowList: allowList,
                initialMembers: initialMembers
            }));
        } else if (configId == 1) {
            // Deploy DAO
            daoContract = new OGREDAO(IOGREDAO.ConstructorParams({
                parentDAO: address(0x0),
                nftAddress: address(nftContract),
                proposalFactoryAddress: address(proposalFactoryContract),
                proposalCost: proposalCost,
                proposalCostToken: address(erc20Contract),
                quorumThreshold: quorumThresh,
                supportThreshold: supportThresh,
                minVoteDuration: minVotePeriod,
                delay: delay,
                allowList: allowList,
                initialMembers: initialMembers
            }));
        }
        _;
    }

    // ========== Configuration Tests ==========

    function test_DeployOGREDAO() public setupDAO(0) {
        assertEq(daoContract.nftAddress(), address(nftContract));
        assertEq(daoContract.proposalFactoryAddress(), address(proposalFactoryContract));
        assertEq(daoContract.delay(), delay);
    }

    function test_SetNewQuorumThreshold() public setupDAO(0) {
        // Set new quorum threshold
        uint256 newQuorumThresh = 7000; // 70%
        daoContract.setQuorumThreshold(newQuorumThresh);

        // Check state
        assertEq(daoContract.quorumThreshold(), newQuorumThresh);
    }

    function test_SetNewSupportThreshold() public setupDAO(0) {
        // Set new support threshold
        uint256 newSupportThresh = 7000; // 70%
        daoContract.setSupportThreshold(newSupportThresh);

        // Check state
        assertEq(daoContract.supportThreshold(), newSupportThresh);
    }

    function test_SetNewMinVoteDuration() public setupDAO(0) {
        // Set new min vote duration
        uint256 newVoteDuration = 400; // 4 mins
        daoContract.setMinVoteDuration(newVoteDuration);

        // Check state
        assertEq(daoContract.minVoteDuration(), newVoteDuration);
    }

    function test_SetNewProposalCost() public setupDAO(0) {
        // Set new proposal cost
        uint256 newProposalCost = 0.0001 ether;
        daoContract.setProposalCost(newProposalCost);

        // Check state
        assertEq(daoContract.proposalCost(), newProposalCost);
    }

    function test_SetNewActionDelay() public setupDAO(0) {
        // Set new action delay
        uint256 newDelay = 20; // 20 seconds
        daoContract.setActionDelay(newDelay);

        // Check state
        assertEq(daoContract.delay(), newDelay);
    }

    // ========== Membership Tests ==========

    function test_RevertIf_NotTokenOwner() public setupDAO(0) {
        // Register member
        uint256 tokenId = 0;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OGREDAO.InvalidSender.selector, user1, user0));
        daoContract.registerMember(tokenId);
    }

    function test_RevertIf_MemberAlreadyRegistered() public setupDAO(0) {
        // Register member
        uint256 tokenId = 0;
        vm.prank(user0);
        daoContract.registerMember(tokenId);
        vm.prank(user0);
        vm.expectRevert(abi.encodeWithSelector(OGREDAO.TokenAlreadyRegistered.selector));
        daoContract.registerMember(tokenId);
    }

    function test_RegisterNewMember() public setupDAO(0) {
        // Register member
        uint256 tokenId = 0;
        uint256 preMemberCount = daoContract.memberCount();
        uint256 preMemberStatus = uint256(daoContract.getMemberStatus(tokenId));

        assertEq(preMemberStatus, 0);

        vm.prank(user0);
        daoContract.registerMember(tokenId);

        assertEq(daoContract.memberCount(), preMemberCount + 1);
        assertEq(uint256(daoContract.getMemberStatus(tokenId)), 1);
    }
    
    // ========== Proposal Tests ==========

    function test_RevertIf_InsufficientNativePayment() public setupDAO(0) {
        uint256 newProposalCost = 0.0001 ether;
        daoContract.setProposalCost(newProposalCost);
        vm.prank(user0);
        vm.expectRevert(abi.encodeWithSelector(OGREDAO.InsufficientPayment.selector, 0, newProposalCost));
        (bool success, ) = daoContract.draftProposal(proposalURI).call{value: 0}("");
        require(success, "proposal call failed");
    }

    function test_DraftAndSetupProposal() public setupDAO(0) {
        uint256 propCount = daoContract.proposalCount();

        // Draft proposal
        vm.prank(user0);
        address propAddress = daoContract.draftProposal(proposalURI);

        assertEq(daoContract.proposalCount(), propCount + 1);
        assertEq(daoContract.proposals(propCount + 1), propAddress);

        // Register members
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(user0);
            daoContract.registerMember(i);
        }

        // Fund DAO address
        vm.deal(address(daoContract), 1 ether);

        // Add action to proposalContract
        proposalContract = OGREProposal(propAddress);
        IActionHopper.Action[] memory passActions = new IActionHopper.Action[](1);
        passActions[0] = IActionHopper.Action({
            target: user1, 
            value: 1 ether, 
            sig: "", 
            data: "",
            ready: 0
        });

        vm.prank(user0);
        proposalContract.setActions(true, passActions);

        // Set vote period
        startTime = block.timestamp + 1;
        endTime = startTime + 300;

        vm.prank(user0);
        proposalContract.setVotingPeriod(startTime, endTime);

        // advance to start time
        vm.warp(startTime);

        // Cast votes on proposalContract
        for (uint256 i = 0; i < 10; i++) {
            vm.prank(user0);
            proposalContract.castVote(i, OGREProposalEnums.VoteDirection.YES); // yes vote
        }

        // Advance network time
        vm.warp(endTime + 1);
    }

    function test_CheckProposalAddress() public setupDAO(0) {
        vm.prank(user0);
        address propAddress = daoContract.draftProposal(proposalURI);
        assertTrue(daoContract.isProposal(propAddress));
        assertFalse(daoContract.isProposal(user0));
    }

    // function testEvaluateProposalPassed() public {
    //     vm.prank(user0);
    //     address propAddress = daoContract.draftProposal(proposalURI);
    //     proposalContract = OGREProposal(propAddress);

    //     // Setup proposalContract (similar to testDraftAndSetupProposal)
    //     // ... (omitted for brevity, but should include the same setup)

    //     vm.prank(user0);
    //     bool passed = daoContract.evaluateProposal(propAddress);
    //     assertTrue(passed);
    //     assertEq(uint256(proposalContract.status()), 3); // passed
    // }

    // function testExecuteProposal() public {
    //     vm.prank(user0);
    //     address propAddress = daoContract.draftProposal(proposalTitle);
    //     proposalContract = OGREProposal(propAddress);

    //     // Setup proposalContract (similar to testDraftAndSetupProposal)
    //     // ... (omitted for brevity, but should include the same setup)

    //     // Wait until ready time
    //     vm.warp(block.timestamp + delay + 1);

    //     vm.prank(user0);
    //     daoContract.executeProposal(propAddress);

    //     assertEq(uint256(proposalContract.status()), 4); // executed
    // }
} 