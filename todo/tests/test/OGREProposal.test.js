const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGREProposal Tests", function () {
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
    let delay = 10; //
    let quorumThresh = 5000; //50%
    let supportThresh = 7000; //70%
    let minVoteTime = 300; //5 mins
    let proposalCost = 0;

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

        //deploy OGREDAO contract
        let OGREDAODeployer = await ethers.getContractFactory("OGREDAO");
        this.OGREDAO = await OGREDAODeployer.deploy(daoName, daoMetadata, this.OGRE721.address, this.OGREProposalFactory.address, proposalCost, userA.address, delay);

        //mint nfts to userA and register dao membership
        let count = 10;
        for (let i = 0; i < count; i++) {
            await this.OGRE721.mint(userA.address, i);
            await this.OGREDAO.registerMember(i);
        }

        //set dao thresholds
        await this.OGREDAO.setQuorumThreshold(quorumThresh);
        await this.OGREDAO.setSupportThreshold(supportThresh);

        //fund dao address
        let amount = "0.001"; //1 ether
        const tx = {
            to: this.OGREDAO.address,
            value: ethers.utils.parseEther(amount),
        }
        await userA.sendTransaction(tx);
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGREProposal contract", async function () {
        let OGREProposalDeployer = await ethers.getContractFactory("OGREProposal");
        this.OGREProposal = await OGREProposalDeployer.deploy(proposalTitle, this.OGREDAO.address, userA.address);
        await this.OGREProposal.deployed();

        let receipt = await this.OGREProposal.deployTransaction.wait();

        expect(await this.OGREProposal.owner()).to.equal(userA.address);
        expect(await this.OGREProposal.proposalTitle()).to.equal(proposalTitle);
        expect(await this.OGREProposal.daoAddress()).to.equal(this.OGREDAO.address);

        expect(receipt.events[2].event).to.equal('StatusUpdated');
        expect(receipt.events[2].args['newStatus']).to.equal("Proposed");
    });

    it("should get action count", async function () {
        expect(await this.OGREProposal.getActionCount()).to.equal(0);
    });

    it("should set new proposal title", async function () {
        let newTitle = "Test Proposal 2.0";
        await this.OGREProposal.setProposalTitle(newTitle);
        expect(await this.OGREProposal.proposalTitle()).to.equal(newTitle);
    });

    it("should configure proposal to be revotable", async function () {
        await this.OGREProposal.configureProposal(true);
        expect(await this.OGREProposal.revotable()).to.equal(true);
    });

    it("should add an action to proposal", async function () {
        let target = userA.address;
        let value = 1;
        let sig = "";
        let data = "0x";

        await this.OGREProposal.addAction(target, value, sig, data);

        expect(await this.OGREProposal.getActionCount()).to.equal(1);
    });

    it("should set voting period", async function () {
        const prevBlockNum = await ethers.provider.getBlockNumber();
        const prevBlock = await ethers.provider.getBlock(prevBlockNum);
        const prevTimestamp = prevBlock.timestamp;

        let votePeriodLength = 300; //in seconds
        startTime = prevTimestamp + 1; //add 1 since start time must be in future
        endTime = startTime + votePeriodLength;

        await this.OGREProposal.setVotingPeriod(startTime, endTime);

        expect(await this.OGREProposal.startTime()).to.equal(startTime);
        expect(await this.OGREProposal.endTime()).to.equal(endTime);
    });

    it("should cancel proposal", async function () {
        let trx = await this.OGREProposal.cancelProposal();
        let receipt = await trx.wait();

        expect(await this.OGREProposal.status()).to.equal(1);

        // expect(receipt.events[1].event).to.equal('ProposalCreated');
        // expect(receipt.events[4].args['daoAddress']).to.equal(this.OGREDAO.address);
        // expect(receipt.events[4].args['creator']).to.equal(userA.address);
    });

    // it("should ...", async function () {});

});