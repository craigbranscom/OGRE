const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ERC721Receivable Tests", function () {
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

    it("should deploy contract inheriting from ERC721Receivable - StubERC721Receivable", async function () {
        let StubERC721ReceivableDeployer = await ethers.getContractFactory("StubERC721Receivable");
        this.StubERC721Receivable = await StubERC721ReceivableDeployer.deploy();
        await this.StubERC721Receivable.deployed();
    });

    it("should trigger onERC721Received on safeTransferFrom call", async function () {
        let tokenId = 0;

        //safe transfer to receivable contract
        //NOTE: must use this syntax for overloaded functions in ethers.js
        let trx = await this.OGRE721["safeTransferFrom(address,address,uint256)"](userA.address, this.StubERC721Receivable.address, tokenId);
        let receipt = await trx.wait();
    });

    it("should send erc721 token", async function () {
        let tokenId = 0;

        let trx = await this.StubERC721Receivable.sendERC721(userB.address, tokenId, this.OGRE721.address);
        let receipt = await trx.wait();

        expect(receipt.events[2].event).to.equal('ERC721Sent');
        expect(receipt.events[2].args['to']).to.equal(userB.address);
        expect(receipt.events[2].args['tokenId']).to.equal(tokenId);
        expect(receipt.events[2].args['erc721Contract']).to.equal(this.OGRE721.address);
    });

    // it("should ...", async function () {});

});