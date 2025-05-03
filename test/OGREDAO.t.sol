// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../src/OGREDAO.sol";
import "../src/samples/SampleERC721.sol";
import "../src/OGREProposal.sol";
import "../src/factories/OGREProposalFactory.sol";
import {OGREDAOStructs} from "../src/libraries/Structs.sol";

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
    string proposalTitle = "Test Proposal";
    uint256 startTime;
    uint256 endTime;

    OGREProposalFactory proposalFactoryContract;
    SampleERC721 nftContract;
    OGREDAO daoContract;
    OGREProposal proposalContract;

    function setUp() public {
        // Get signers
        user0 = makeAddr("user0");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy contracts
        proposalFactoryContract = new OGREProposalFactory();
        nftContract = new SampleERC721(name, symbol);
        daoContract = new OGREDAO(OGREDAOStructs.ConstructorParams({
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

        // Mint NFTs to user0
        for (uint256 i = 0; i < 10; i++) {
            nftContract.mint(user0, i);
        }
    }

    // ========== Configuration Tests ==========

    function test_DeployOGREDAO() public view {
        assertEq(daoContract.nftAddress(), address(nftContract));
        assertEq(daoContract.proposalFactoryAddress(), address(proposalFactoryContract));
        assertEq(daoContract.delay(), delay);
        
        // assertTrue(daoContract.hasRole(daoAdminRole, user0));
        // assertFalse(daoContract.hasRole(daoAdminRole, user1));
        // assertEq(daoContract.getRoleAdmin(daoInviteRole), daoAdminRole);
    }

    function test_SetNewQuorumThreshold() public {
        uint256 newQuorumThresh = 7000; // 70%
        daoContract.setQuorumThreshold(newQuorumThresh);
        assertEq(daoContract.quorumThreshold(), newQuorumThresh);
    }

    function test_SetNewSupportThreshold() public {
        uint256 newSupportThresh = 7000; // 70%
        daoContract.setSupportThreshold(newSupportThresh);
        assertEq(daoContract.supportThreshold(), newSupportThresh);
    }

    function test_SetNewMinVoteDuration() public {
        uint256 newVoteDuration = 400; // 4 mins
        daoContract.setMinVoteDuration(newVoteDuration);
        assertEq(daoContract.minVoteDuration(), newVoteDuration);
    }

    function test_SetNewProposalCost() public {
        uint256 newProposalCost = 0.0001 ether;
        daoContract.setProposalCost(newProposalCost);
        assertEq(daoContract.proposalCost(), newProposalCost);
    }

    function test_SetNewActionDelay() public {
        uint256 newDelay = 20; // 20 seconds
        daoContract.setActionDelay(newDelay);
        assertEq(daoContract.delay(), newDelay);
    }

    // ========== Membership Tests ==========

    function test_RevertIf_NotTokenOwner() public {
        uint256 tokenId = 0;
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(OGREDAO.InvalidSender.selector, user1, user0));
        daoContract.registerMember(tokenId);
    }

    function test_RevertIf_MemberAlreadyRegistered() public {
        uint256 tokenId = 0;
        vm.prank(user0);
        daoContract.registerMember(tokenId);
        vm.prank(user0);
        vm.expectRevert(abi.encodeWithSelector(OGREDAO.TokenAlreadyRegistered.selector));
        daoContract.registerMember(tokenId);
    }

    function test_RegisterNewMember() public {
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

    function test_RevertIf_InsufficientPayment() public {
        uint256 newProposalCost = 0.0001 ether;
        daoContract.setProposalCost(newProposalCost);
        vm.prank(user0);
        vm.expectRevert(abi.encodeWithSelector(OGREDAO.InsufficientPayment.selector, 0, newProposalCost));
        //solhint-disable-next-line
        daoContract.draftProposal(proposalTitle).call{value: 0}("");
    }

    // function testDraftAndSetupProposal() public {
    //     uint256 propCount = daoContract.proposalCount();

    //     vm.prank(user0);
    //     address propAddress = daoContract.draftProposal(proposalTitle);

    //     assertEq(daoContract.proposalCount(), propCount + 1);
    //     assertEq(daoContract.proposals(propCount + 1), propAddress);

    //     // Register remaining members
    //     for (uint256 i = 1; i < 10; i++) {
    //         vm.prank(user0);
    //         daoContract.registerMember(i);
    //     }

    //     // Fund DAO address
    //     vm.deal(address(daoContract), 0.0001 ether);

    //     // Add action to proposalContract
    //     proposalContract = OGREProposal(propAddress);
    //     address target = user0;
    //     uint256 value = 1;
    //     string memory sig = "";
    //     bytes memory data = "";

    //     vm.prank(user0);
    //     proposalContract.addAction(target, value, sig, data);

    //     // Set vote period
    //     startTime = block.timestamp + 1;
    //     endTime = startTime + 300;

    //     vm.prank(user0);
    //     proposalContract.setVotingPeriod(startTime, endTime);

    //     // Cast votes on proposalContract
    //     for (uint256 i = 0; i < 10; i++) {
    //         vm.prank(user0);
    //         proposalContract.castVote(i, 1); // yes vote
    //     }

    //     // Advance network time
    //     vm.warp(endTime + 1);
    // }

    // function testCheckProposalAddress() public {
    //     vm.prank(user0);
    //     address propAddress = daoContract.draftProposal(proposalTitle);
    //     assertTrue(daoContract.isProposal(propAddress));
    //     assertFalse(daoContract.isProposal(user0));
    // }

    // function testEvaluateProposalPassed() public {
    //     vm.prank(user0);
    //     address propAddress = daoContract.draftProposal(proposalTitle);
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