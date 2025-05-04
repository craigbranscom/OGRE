const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGREProposalFactory Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //ogre proposal
    let title = "Test Proposal";

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGREProposalFactory contract", async function () {
        let OGREProposalFactoryDeployer = await ethers.getContractFactory("OGREProposalFactory");
        this.OGREProposalFactory = await OGREProposalFactoryDeployer.deploy();
        await this.OGREProposalFactory.deployed();
    });

    it("should successfully produce OGREProposal contract", async function () {
        let trx = await this.OGREProposalFactory.produceOGREProposal(title, this.OGREProposalFactory.address, userA.address);
        let receipt = await trx.wait();

        expect(receipt.events[3].event).to.equal('ContractProduced');
        expect(receipt.events[3].args['factoryAddress']).to.equal(this.OGREProposalFactory.address);
        expect(receipt.events[3].args['producer']).to.equal(userA.address);
    });

});