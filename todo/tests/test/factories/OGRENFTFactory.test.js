const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGRE721Factory Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //erc721
    let name = "Test NFTs";
    let symbol = "TEST";

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGRE721Factory contract", async function () {
        let OGRE721FactoryDeployer = await ethers.getContractFactory("OGRE721Factory");
        this.OGRE721Factory = await OGRE721FactoryDeployer.deploy();
        await this.OGRE721Factory.deployed();
    });

    it("should successfully produce OGRE721 contract", async function () {
        let owner = userA.address;

        let trx = await this.OGRE721Factory.produceOGRE721(name, symbol, owner);
        let receipt = await trx.wait();

        expect(receipt.events[2].event).to.equal('ContractProduced');
        expect(receipt.events[2].args['factoryAddress']).to.equal(this.OGRE721Factory.address);
    });

});