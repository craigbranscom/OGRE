const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGREMarket Tests", function () {
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

    //ogre market
    let orderFee = 0;
    let feeRecipient;
    let minOrderLength = 60; //in seconds

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();

        //deploy OGREMarketFactory Contract
        // let OGREMarketFactoryDeployer = await ethers.getContractFactory("OGREMarketFactory");
        // this.OGREMarketFactory = await OGREMarketFactoryDeployer.deploy();
        // await this.OGREMarketFactory.deployed();

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

        //deploy OGREDAO contract
        let OGREDAODeployer = await ethers.getContractFactory("OGREDAO");
        this.OGREDAO = await OGREDAODeployer.deploy(daoName, daoMetadata, this.OGRE721.address, this.OGREProposalFactory.address, proposalCost, userA.address, delay);
        await this.OGREDAO.deployed();

        //deploy OGRE20 contract
        let OGRE20Deployer = await ethers.getContractFactory("OGRE20");
        this.OGRE20 = await OGRE20Deployer.deploy(name, symbol, userA.address);
        await this.OGRE20.deployed();

        //mint tokens to userB
        let amount = 100;
        await this.OGRE20.mint(userB.address, amount);
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGREMarket contract", async function () {
        feeRecipient = userC.address;

        let OGREMarketDeployer = await ethers.getContractFactory("OGREMarket");
        this.OGREMarket = await OGREMarketDeployer.deploy(userA.address, userA.address, orderFee, feeRecipient);
        await this.OGREDAO.deployed();

        expect(await this.OGREMarket.daoAddress()).to.equal(userA.address);
        expect(await this.OGREMarket.orderFee()).to.equal(orderFee);
        expect(await this.OGREMarket.feeRecipient()).to.equal(feeRecipient);
    });

    it("should set new order fee", async function () {
        let newOrderFee = ethers.utils.parseEther("0.001");

        await this.OGREMarket.setOrderFee(newOrderFee);

        expect(await this.OGREMarket.orderFee()).to.equal(newOrderFee);
    });

    it("should fail to create order - erc721 contract not allowed", async function () {
        let orderType = 0; //ASK
        let tokenId = 1;
        let amount = 10;
        let orderHash = await this.OGREMarket.calcOrderHash(this.OGRE721.address, tokenId, this.OGRE20.address, amount);
        let itemHash = await this.OGREMarket.calcItemHash(this.OGRE721.address, tokenId);

        //attemp to create order
        this.OGREMarket = this.OGREMarket.connect(userA);
        await expect(
            this.OGREMarket.createOrder(orderType, this.OGRE721.address, tokenId, this.OGRE20.address, amount, {value: ethers.utils.parseEther("0.001")})
        ).to.be.revertedWith(
            "erc721 contract not allowed"
        );
    });

    it("should add erc20 and erc721 contracts to allowlist", async function () {
        await this.OGREMarket.setContractAllowed(this.OGRE20.address, true);
        await this.OGREMarket.setContractAllowed(this.OGRE721.address, true);

        expect(await this.OGREMarket.allowedContracts(this.OGRE20.address)).to.equal(true);
        expect(await this.OGREMarket.allowedContracts(this.OGRE721.address)).to.equal(true);
        expect(await this.OGREMarket.allowedContracts(this.OGREDAO.address)).to.equal(false);
    });

    it("should calculate order hash", async function () {
        let tokenId = 1;
        let amount = 10;

        let res = await this.OGREMarket.calcOrderHash(this.OGRE721.address, tokenId, this.OGRE20.address, amount);
        // console.log(res);
    });

    it("should calculate item hash", async function () {
        let tokenId = 1;

        let res = await this.OGREMarket.calcItemHash(this.OGRE721.address, tokenId);
        // console.log(res);
    });   

    it("should create new ask order", async function () {
        let orderType = 0; //ASK
        let tokenId = 1;
        let amount = 10;

        await this.OGRE721.approve(this.OGREMarket.address, tokenId);

        let orderHash = await this.OGREMarket.calcOrderHash(this.OGRE721.address, tokenId, this.OGRE20.address, amount);
        let itemHash = await this.OGREMarket.calcItemHash(this.OGRE721.address, tokenId);

        //create order
        let trx = await this.OGREMarket.createOrder(orderType, this.OGRE721.address, tokenId, this.OGRE20.address, amount, {value: ethers.utils.parseEther("0.001")});
        let receipt = await trx.wait();

        let order = await this.OGREMarket.orders(orderHash);
        let listed = await this.OGREMarket.listedItems(itemHash);

        expect(receipt.events[0].event).to.equal('OrderCreated');
        expect(receipt.events[0].args['orderHash']).to.equal(orderHash);
        expect(receipt.events[0].args['orderType']).to.equal(0);
        expect(receipt.events[0].args['creator']).to.equal(userA.address);
        expect(receipt.events[0].args['erc721Address']).to.equal(this.OGRE721.address);
        expect(receipt.events[0].args['tokenId']).to.equal(tokenId);
        expect(receipt.events[0].args['erc20Address']).to.equal(this.OGRE20.address);
        expect(receipt.events[0].args['amount']).to.equal(amount);
        
        expect(order["creator"]).to.equal(userA.address);
        expect(order["erc721Address"]).to.equal(this.OGRE721.address);
        expect(order["tokenId"]).to.equal(tokenId);
        expect(order["erc20Address"]).to.equal(this.OGRE20.address);
        expect(order["amount"]).to.equal(amount);

        expect(listed).to.equal(orderHash);
    });

    it("should fulfill ask order", async function () {
        let orderType = 1; //BID
        let tokenId = 1;
        let amount = 10;
        let orderHash = await this.OGREMarket.calcOrderHash(this.OGRE721.address, tokenId, this.OGRE20.address, amount);
        let itemHash = await this.OGREMarket.calcItemHash(this.OGRE721.address, tokenId);

        //approve
        this.OGRE20 = this.OGRE20.connect(userB);
        await this.OGRE20.approve(this.OGREMarket.address, amount);

        //create order
        this.OGREMarket = this.OGREMarket.connect(userB);
        let trx = await this.OGREMarket.createOrder(orderType, this.OGRE721.address, tokenId, this.OGRE20.address, amount, {value: ethers.utils.parseEther("0.001")});
        let receipt = await trx.wait();
        expect(receipt.events[4].event).to.equal('OrderFulfilled');
        expect(receipt.events[4].args['orderHash']).to.equal(orderHash);
        
        let order = await this.OGREMarket.orders(orderHash);
        expect(order["orderType"]).to.equal(0);
        expect(order["creator"]).to.equal(ethers.constants.AddressZero);
        expect(order["erc721Address"]).to.equal(ethers.constants.AddressZero);
        expect(order["tokenId"]).to.equal(0);
        expect(order["erc20Address"]).to.equal(ethers.constants.AddressZero);
        expect(order["amount"]).to.equal(0);

        let listing = await this.OGREMarket.listedItems(itemHash);
        expect(listing).to.equal("0x0000000000000000000000000000000000000000000000000000000000000000");

        expect(await this.OGRE721.ownerOf(tokenId)).to.equal(userB.address);
        expect(await this.OGRE20.balanceOf(userA.address)).to.equal(amount);
    });

    it("should cancel existing order", async function () {
        let orderType = 0; //ASK
        let tokenId = 3;
        let amount = 10;
        let orderHash = await this.OGREMarket.calcOrderHash(this.OGRE721.address, tokenId, this.OGRE20.address, amount);
        let itemHash = await this.OGREMarket.calcItemHash(this.OGRE721.address, tokenId);

        //approve token id
        this.OGRE721 = this.OGRE721.connect(userA);
        await this.OGRE721.approve(this.OGREMarket.address, tokenId);

        //create order
        this.OGREMarket = this.OGREMarket.connect(userA);
        await this.OGREMarket.createOrder(orderType, this.OGRE721.address, tokenId, this.OGRE20.address, amount, {value: ethers.utils.parseEther("0.001")});

        //cancel order
        let trx = await this.OGREMarket.cancelOrder(orderHash);
        let receipt = await trx.wait();
        expect(receipt.events[0].event).to.equal('OrderCancelled');
        expect(receipt.events[0].args['orderHash']).to.equal(orderHash);
        
        let order = await this.OGREMarket.orders(orderHash);
        expect(order["orderType"]).to.equal(0);
        expect(order["creator"]).to.equal(ethers.constants.AddressZero);
        expect(order["erc721Address"]).to.equal(ethers.constants.AddressZero);
        expect(order["tokenId"]).to.equal(0);
        expect(order["erc20Address"]).to.equal(ethers.constants.AddressZero);
        expect(order["amount"]).to.equal(0);

        let listing = await this.OGREMarket.listedItems(itemHash);
        expect(listing).to.equal("0x0000000000000000000000000000000000000000000000000000000000000000");
    });

    // it("should ...", async function () {});

});