const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGRE721 Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //erc721
    let name = "Test NFTs";
    let symbol = "TEST";
    let owner;
    let maxSupply = 100;

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();

        owner = userA.address;
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGRE721 contract", async function () {
        let OGRE721Deployer = await ethers.getContractFactory("OGRE721");
        this.OGRE721 = await OGRE721Deployer.deploy(name, symbol, owner);
        await this.OGRE721.deployed();
    });

    it("should fail to mint token - mint to zero address", async function () {
        let tokenId = 0;
        await expect(
            this.OGRE721.mint(ethers.constants.AddressZero, tokenId)
        ).to.be.revertedWith("ERC721: mint to the zero address");
    });

    it("should successfully mint token", async function () {
        let tokenId = 0;
        await this.OGRE721.mint(userA.address, tokenId);
        expect(await this.OGRE721.ownerOf(tokenId)).to.equal(userA.address);
    });

    it("should successfully burn token", async function () {
        let tokenId = 0;
        await this.OGRE721.burn(tokenId);
        await expect(
            this.OGRE721.ownerOf(tokenId)
        ).to.be.revertedWith("ERC721: owner query for nonexistent token");
    });

});