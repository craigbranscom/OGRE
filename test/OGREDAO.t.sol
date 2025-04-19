// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import "../src/OGREDAO.sol";
import "../src/samples/SampleERC721.sol";
import "../src/OGREProposal.sol";
import "../src/factories/OGREProposalFactory.sol";

contract OGREDAOTest is Test {
    // Signers
    address userA;
    address userB;
    address userC;

    // ERC721
    string name = "Test NFTs";
    string symbol = "TEST";
    uint256 maxSupply = 100;
    address owner;

    // OGRE DAO
    string daoName = "Test DAO";
    string daoMetadata = "https://some-api-endpoint.com/";
    uint256 delay = 10; // in seconds
    uint256 quorumThresh = 5000; // 50%
    uint256 supportThresh = 6000; // 60%
    uint256 minVotePeriod = 300; // 5 mins
    uint256 proposalCost = 0;
    bytes32 daoAdminRole = keccak256("DAO_ADMIN");
    bytes32 daoInviteRole = keccak256("DAO_INVITE");

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
        userA = makeAddr("userA");
        userB = makeAddr("userB");
        userC = makeAddr("userC");

        // Deploy contracts
        proposalFactoryContract = new OGREProposalFactory();
        nftContract = new SampleERC721(name, symbol);
        daoContract = new OGREDAO(
            daoName,
            daoMetadata,
            address(nftContract),
            address(proposalFactoryContract),
            proposalCost,
            userA,
            delay
        );

        // Mint NFTs to userA
        for (uint256 i = 0; i < 10; i++) {
            nftContract.mint(userA, i);
        }
    }

    function test_DeployOGREDAO() public {
        assertEq(daoContract.daoName(), daoName);
        assertEq(daoContract.nftAddress(), address(nftContract));
        assertEq(daoContract.proposalFactoryAddress(), address(proposalFactoryContract));
        assertEq(daoContract.delay(), delay);
        
        assertTrue(daoContract.hasRole(daoAdminRole, userA));
        assertFalse(daoContract.hasRole(daoAdminRole, userB));
        assertEq(daoContract.getRoleAdmin(daoInviteRole), daoAdminRole);
    }

    // function testSetNewDAOName() public {
    //     string memory newName = "Test DAO 2.0";
    //     daoContract.setDAOName(newName);
    //     assertEq(daoContract.daoName(), newName);
    // }

    // function testSetNewQuorumThreshold() public {
    //     daoContract.setQuorumThreshold(quorumThresh);
    //     assertEq(daoContract.quorumThreshold(), quorumThresh);
    // }

    // function testSetNewSupportThreshold() public {
    //     daoContract.setSupportThreshold(supportThresh);
    //     assertEq(daoContract.supportThreshold(), supportThresh);
    // }

    // function testSetNewMinVotePeriod() public {
    //     daoContract.setMinVotePeriod(minVotePeriod);
    //     assertEq(daoContract.minVotePeriod(), minVotePeriod);
    // }

    // function testCheckTokenOwnership() public {
    //     uint256 tokenId = 0;
    //     assertTrue(daoContract.isTokenOwner(tokenId, userA));
    //     assertFalse(daoContract.isTokenOwner(tokenId, userB));
    // }

    // function testRegisterNewMember() public {
    //     uint256 tokenId = 0;
    //     uint256 memberCount = daoContract.memberCount();
    //     uint256 memberStatus = uint256(daoContract.getMemberStatus(tokenId));

    //     assertEq(memberStatus, 0);

    //     vm.prank(userA);
    //     daoContract.registerMember(tokenId);

    //     assertEq(daoContract.memberCount(), memberCount + 1);
    //     assertEq(uint256(daoContract.getMemberStatus(tokenId)), 2);
    // }

    // function test_RevertIf_MemberAlreadyRegistered() public {
    //     uint256 tokenId = 0;
    //     vm.prank(userA);
    //     daoContract.registerMember(tokenId);
    //     vm.prank(userA);
    //     daoContract.registerMember(tokenId);
    // }

    // function testDraftAndSetupProposal() public {
    //     uint256 propCount = daoContract.proposalCount();

    //     vm.prank(userA);
    //     address propAddress = daoContract.draftProposal(proposalTitle);

    //     assertEq(daoContract.proposalCount(), propCount + 1);
    //     assertEq(daoContract.proposals(propCount + 1), propAddress);

    //     // Register remaining members
    //     for (uint256 i = 1; i < 10; i++) {
    //         vm.prank(userA);
    //         daoContract.registerMember(i);
    //     }

    //     // Fund DAO address
    //     vm.deal(address(daoContract), 0.0001 ether);

    //     // Add action to proposalContract
    //     proposalContract = OGREProposal(propAddress);
    //     address target = userA;
    //     uint256 value = 1;
    //     string memory sig = "";
    //     bytes memory data = "";

    //     vm.prank(userA);
    //     proposalContract.addAction(target, value, sig, data);

    //     // Set vote period
    //     startTime = block.timestamp + 1;
    //     endTime = startTime + 300;

    //     vm.prank(userA);
    //     proposalContract.setVotingPeriod(startTime, endTime);

    //     // Cast votes on proposalContract
    //     for (uint256 i = 0; i < 10; i++) {
    //         vm.prank(userA);
    //         proposalContract.castVote(i, 1); // yes vote
    //     }

    //     // Advance network time
    //     vm.warp(endTime + 1);
    // }

    // function testCheckProposalAddress() public {
    //     vm.prank(userA);
    //     address propAddress = daoContract.draftProposal(proposalTitle);
    //     assertTrue(daoContract.isProposal(propAddress));
    //     assertFalse(daoContract.isProposal(userA));
    // }

    // function testEvaluateProposalPassed() public {
    //     vm.prank(userA);
    //     address propAddress = daoContract.draftProposal(proposalTitle);
    //     proposalContract = OGREProposal(propAddress);

    //     // Setup proposalContract (similar to testDraftAndSetupProposal)
    //     // ... (omitted for brevity, but should include the same setup)

    //     vm.prank(userA);
    //     bool passed = daoContract.evaluateProposal(propAddress);
    //     assertTrue(passed);
    //     assertEq(uint256(proposalContract.status()), 3); // passed
    // }

    // function testExecuteProposal() public {
    //     vm.prank(userA);
    //     address propAddress = daoContract.draftProposal(proposalTitle);
    //     proposalContract = OGREProposal(propAddress);

    //     // Setup proposalContract (similar to testDraftAndSetupProposal)
    //     // ... (omitted for brevity, but should include the same setup)

    //     // Wait until ready time
    //     vm.warp(block.timestamp + delay + 1);

    //     vm.prank(userA);
    //     daoContract.executeProposal(propAddress);

    //     assertEq(uint256(proposalContract.status()), 4); // executed
    // }
} 