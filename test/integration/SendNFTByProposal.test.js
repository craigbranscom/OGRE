const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Send NFT By Proposal Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //erc721
    let name = "Test NFTs";
    let symbol = "TEST";
    let maxSupply = 10;
    let owner;

    //ogre dao
    let daoName = "Test DAO";
    let daoMetadata = "https://some-api-endpoint.com/";
    let delay = 10; //in seconds
    let quorumThresh = 5000; //50%
    let supportThresh = 6000; //60%
    let minVotePeriod = 300; //5 mins
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
        await this.OGREDAO.deployed();

        //setup dao
        await this.OGREDAO.setQuorumThreshold(quorumThresh);
        await this.OGREDAO.setSupportThreshold(supportThresh);
        await this.OGREDAO.setMinVotePeriod(minVotePeriod);

        //mint all nfts and register
        for (let i = 0; i < maxSupply; i++) {
            await this.OGRE721.mint(userA.address, i);
            await this.OGREDAO.registerMember(i);
        }

        //transfer nft to DAO
        await this.OGRE721["safeTransferFrom(address,address,uint256)"](userA.address, this.OGREDAO.address, 0);
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should draft and setup proposal - transfer nft 0 to userB", async function () {
        //draft proposal
        let trx = await this.OGREDAO.draftProposal(proposalTitle);
        let receipt = await trx.wait();

        //attach new proposal contract to state
        this.OGREProposalDeployer = await ethers.getContractFactory("OGREProposal");
        this.OGREProposal = this.OGREProposalDeployer.attach(receipt.events[4].args['proposal']);

        //add safeTransferFrom action to proposal
        let target = this.OGRE721.address;
        let value = 0;
        let sig = "safeTransferFrom(address,address,uint256)";
        let data = ethers.utils.defaultAbiCoder.encode(["address", "address", "uint256"], [this.OGREDAO.address, userB.address, 0]);
        await this.OGREProposal.addAction(target, value, sig, data);

        //set vote period
        const prevBlockNum = await ethers.provider.getBlockNumber();
        const prevBlock = await ethers.provider.getBlock(prevBlockNum);
        const prevTimestamp = prevBlock.timestamp;

        let votePeriodLength = 300; //in seconds
        startTime = prevTimestamp + 1; //add 1 since start time must be in future
        endTime = startTime + votePeriodLength;

        await this.OGREProposal.setVotingPeriod(startTime, endTime);

        //cast all votes on proposal (except token owned by dao)
        for (let i = 1; i < maxSupply; i++) {
            await this.OGREProposal.castVote(i, 1); //yes vote
        }

        //advance network time
        await network.provider.send("evm_setNextBlockTimestamp", [endTime + 1]); //add one to go past end time
        await network.provider.send("evm_mine") // this one will have end time as its timestamp
    });

    it("should evaluate proposal - passed", async function () {
        let trx = await this.OGREDAO.evaluateProposal(this.OGREProposal.address);
        let receipt = await trx.wait();

        expect(receipt.events[1].event).to.equal('ProposalEvaluated');
        expect(receipt.events[1].args['quorumPassed']).to.equal(true);
        expect(receipt.events[1].args['supportPassed']).to.equal(true);
        expect(receipt.events[1].args['totalVotes']).to.equal(maxSupply - 1);
        expect(receipt.events[1].args['quorumVotesThreshold']).to.equal(5);
        expect(receipt.events[1].args['supportVotesThreshold']).to.equal(6);

        expect(await this.OGREProposal.status()).to.equal(3); //passed
    });

    it("should execute proposal", async function () {
        //wait until ready time
        await network.provider.send("evm_increaseTime", [delay + 1]);
        await network.provider.send("evm_mine");

        expect(await this.OGRE721.ownerOf(0)).to.equal(this.OGREDAO.address);

        //execute proposal
        let trx = await this.OGREDAO.executeProposal(this.OGREProposal.address);
        let receipt = await trx.wait();

        expect(await this.OGREProposal.status()).to.equal(4); //executed

        expect(receipt.events[3].event).to.equal('ProposalExecuted');
        expect(receipt.events[3].args['proposal']).to.equal(this.OGREProposal.address);

        expect(await this.OGRE721.ownerOf(0)).to.equal(userB.address);
    });

    // it("should ...", async function () {});

});