const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGREFactory Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy contract inheriting from OGREFactory - StubOGREFactory", async function () {
        let StubOGREFactoryDeployer = await ethers.getContractFactory("StubOGREFactory");
        this.StubOGREFactory = await StubOGREFactoryDeployer.deploy();
        await this.StubOGREFactory.deployed();
    });

    it("should trigger ContractProduced event", async function () {
        let trx = await this.StubOGREFactory.produceContract(userB.address, userA.address);
        let receipt = await trx.wait();

        expect(receipt.events[0].event).to.equal('ContractProduced');
        expect(receipt.events[0].args['contractAddress']).to.equal(userB.address);
        expect(receipt.events[0].args['factoryAddress']).to.equal(this.StubOGREFactory.address);
        expect(receipt.events[0].args['producer']).to.equal(userA.address);
    });

    // it("should ...", async function () {});

});