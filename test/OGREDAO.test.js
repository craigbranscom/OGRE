const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGREDAO Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //erc721
    let name = "Test NFTs";
    let symbol = "TEST";
    let maxSupply = 100;
    let owner;

    //ogre dao
    let daoName = "Test DAO";
    let daoMetadata = "https://some-api-endpoint.com/";
    let delay = 10; //in seconds
    let quorumThresh = 5000; //50%
    let supportThresh = 6000; //60%
    let minVotePeriod = 300; //5 mins
    let proposalCost = 0;
    let daoAdminRole = "0xf591dda2e9b53c180cef2a1f29bc285ccc0649b7a0efc8de2ec0cfe024d46b96";
    let daoInviteRole = "0xf8450c7be9c60a2b1311317b8f68d216b82a7116d8d7c927eb7554832e0cb05a";

    //ogre proposal
    let proposalTitle = "Test Proposal";
    let startTime;
    let endTime;

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();

        //deploy OGREProposalFactory Contract
        let OGREProposalFactoryDeployer = await ethers.getContractFactory("OGREProposalFactory");
        this.OGREProposalFactory = await OGREProposalFactoryDeployer.deploy();
        await this.OGREProposalFactory.deployed();

        //deploy OGRE721 contract
        let OGRE721Deployer = await ethers.getContractFactory("OGRE721");
        owner = userA.address;
        this.OGRE721 = await OGRE721Deployer.deploy(name, symbol, owner);
        await this.OGRE721.deployed();

        //mint nfts to userA
        let count = 10;
        for (let i = 0; i < count; i++) {
            await this.OGRE721.mint(userA.address, i);
        }
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGREDAO contract", async function () {
        let OGREDAODeployer = await ethers.getContractFactory("OGREDAO");
        this.OGREDAO = await OGREDAODeployer.deploy(daoName, daoMetadata, this.OGRE721.address, this.OGREProposalFactory.address, proposalCost, userA.address, delay);
        await this.OGREDAO.deployed();

        expect(await this.OGREDAO.daoName()).to.equal(daoName);
        expect(await this.OGREDAO.nftAddress()).to.equal(this.OGRE721.address);
        expect(await this.OGREDAO.proposalFactoryAddress()).to.equal(this.OGREProposalFactory.address);
        expect(await this.OGREDAO.delay()).to.equal(delay);
        
        expect(await this.OGREDAO.hasRole(daoAdminRole, userA.address)).to.equal(true);
        expect(await this.OGREDAO.hasRole(daoAdminRole, userB.address)).to.equal(false);
        expect(await this.OGREDAO.getRoleAdmin(daoInviteRole)).to.equal(daoAdminRole);
    });

    it("should set new dao name", async function () {
        daoName = "Test DAO 2.0"

        await this.OGREDAO.setDAOName(daoName);

        expect(await this.OGREDAO.daoName()).to.equal(daoName);
    });

    it("should set new quorum threshold", async function () {
        await this.OGREDAO.setQuorumThreshold(quorumThresh);

        expect(await this.OGREDAO.quorumThreshold()).to.equal(quorumThresh);
    });

    it("should set new support threshold", async function () {
        await this.OGREDAO.setSupportThreshold(supportThresh);

        expect(await this.OGREDAO.supportThreshold()).to.equal(supportThresh);
    });

    it("should set new min vote period", async function () {
        await this.OGREDAO.setMinVotePeriod(minVotePeriod);

        expect(await this.OGREDAO.minVotePeriod()).to.equal(minVotePeriod);
    });

    it("should check token ownership", async function () {
        let tokenId = 0;
        expect(await this.OGREDAO.isTokenOwner(tokenId, userA.address)).to.equal(true);
        expect(await this.OGREDAO.isTokenOwner(tokenId, userB.address)).to.equal(false);
    });

    it("should register a new member to dao", async function () {
        let tokenId = 0;
        let memberCount = await this.OGREDAO.memberCount();
        let memberStatus = await this.OGREDAO.getMemberStatus(tokenId);

        expect(memberStatus).to.equal(0);

        let trx = await this.OGREDAO.registerMember(tokenId);
        let receipt = await trx.wait();

        expect(await this.OGREDAO.memberCount()).to.equal(memberCount + 1);
        expect(await this.OGREDAO.getMemberStatus(tokenId)).to.equal(2);

        expect(receipt.events[0].event).to.equal('MemberRegistered');
        expect(receipt.events[0].args['daoAddress']).to.equal(this.OGREDAO.address);
        expect(receipt.events[0].args['nftAddress']).to.equal(this.OGRE721.address);
        expect(receipt.events[0].args['tokenId']).to.equal(tokenId);
        expect(receipt.events[0].args['memberAddress']).to.equal(userA.address);
    });

    it("should fail to register member - already registered", async function () {
        let tokenId = 0;
        await expect(
            this.OGREDAO.registerMember(tokenId)
        ).to.be.revertedWith("token is already registered");
    });

    it("should draft and setup a new proposal", async function () {
        let propCount = await this.OGREDAO.proposalCount();

        let trx = await this.OGREDAO.draftProposal(proposalTitle);
        let receipt = await trx.wait();

        expect(await this.OGREDAO.proposalCount()).to.equal(propCount + 1);

        expect(receipt.events[4].event).to.equal('ProposalCreated');
        expect(receipt.events[4].args['daoAddress']).to.equal(this.OGREDAO.address);
        expect(receipt.events[4].args['creator']).to.equal(userA.address);

        //attach new proposal contract to state
        this.OGREProposalDeployer = await ethers.getContractFactory("OGREProposal");
        this.OGREProposal = this.OGREProposalDeployer.attach(receipt.events[4].args['proposal']);

        expect(await this.OGREDAO.proposals(propCount + 1)).to.equal(this.OGREProposal.address);

        //register remaining members
        let members = 10;
        for (let i = 1; i < members; i++) {
            await this.OGREDAO.registerMember(i);
        }

        //fund dao address
        let amount = "0.0001";
        const tx = {
            to: this.OGREDAO.address,
            value: ethers.utils.parseEther(amount),
        }
        await userA.sendTransaction(tx);

        //add action to proposal
        let target = userA.address;
        let value = 1;
        let sig = "";
        let data = "0x";

        await this.OGREProposal.addAction(target, value, sig, data);

        //set vote period
        const prevBlockNum = await ethers.provider.getBlockNumber();
        const prevBlock = await ethers.provider.getBlock(prevBlockNum);
        const prevTimestamp = prevBlock.timestamp;

        let votePeriodLength = 300; //in seconds
        startTime = prevTimestamp + 1; //add 1 since start time must be in future
        endTime = startTime + votePeriodLength;

        await this.OGREProposal.setVotingPeriod(startTime, endTime);

        //cast votes on proposal
        let votes = 10;
        for (let i = 0; i < votes; i++) {
            await this.OGREProposal.castVote(i, 1); //yes vote
        }

        //advance network time
        await network.provider.send("evm_setNextBlockTimestamp", [endTime + 1]); //add one to go past end time
        await network.provider.send("evm_mine") // this one will have end time as its timestamp
    });

    it("should check whether address is a proposal created through dao", async function () {
        expect(await this.OGREDAO.isProposal(this.OGREProposal.address)).to.equal(true);
        expect(await this.OGREDAO.isProposal(userA.address)).to.equal(false);
    });

    it("should evaluate proposal - passed", async function () {
        let trx = await this.OGREDAO.evaluateProposal(this.OGREProposal.address);
        let receipt = await trx.wait();

        expect(receipt.events[1].event).to.equal('ProposalEvaluated');
        expect(receipt.events[1].args['quorumPassed']).to.equal(true);
        expect(receipt.events[1].args['supportPassed']).to.equal(true);
        expect(receipt.events[1].args['totalVotes']).to.equal(10);
        expect(receipt.events[1].args['quorumVotesThreshold']).to.equal(5);
        expect(receipt.events[1].args['supportVotesThreshold']).to.equal(6);

        expect(await this.OGREProposal.status()).to.equal(3); //passed

    });

    it("should execute proposal", async function () {
        //wait until ready time
        await network.provider.send("evm_increaseTime", [delay + 1]);
        await network.provider.send("evm_mine");

        let trx = await this.OGREDAO.executeProposal(this.OGREProposal.address);
        let receipt = await trx.wait();

        expect(await this.OGREProposal.status()).to.equal(4); //executed

        expect(receipt.events[1].event).to.equal('ProposalExecuted');
        expect(receipt.events[1].args['proposal']).to.equal(this.OGREProposal.address);
    });

    // it("should ...", async function () {});

});