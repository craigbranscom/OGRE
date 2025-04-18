const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGREDAOFactory Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //ogre dao
    let daoName = "Test DAO";
    let daoMetadata = "https://some-api-endpoint.com/";
    let daoDelay = 300; //5 mins
    let proposalCost = 0;

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGREDAOFactory contract", async function () {
        let OGREDAOFactoryDeployer = await ethers.getContractFactory("OGREDAOFactory");
        this.OGREDAOFactory = await OGREDAOFactoryDeployer.deploy();
        await this.OGREDAOFactory.deployed();
    });

    it("should successfully produce OGREDAO contract", async function () {
        let trx = await this.OGREDAOFactory.produceOGREDAO(daoName, daoMetadata, userA.address, userA.address, proposalCost, userA.address, daoDelay);
        let receipt = await trx.wait();

        expect(receipt.events[4].event).to.equal('ContractProduced');
        expect(receipt.events[4].args['factoryAddress']).to.equal(this.OGREDAOFactory.address);
    });

});