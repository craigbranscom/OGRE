const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OGRETokenizedMarket Tests", function () {
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
    // let daoName = "Test DAO";
    // let daoMetadata = "https://some-api-endpoint.com/";
    // let delay = 10; //in seconds
    // let quorumThresh = 5000; //50%
    // let supportThresh = 6000; //60%
    // let minVotePeriod = 300; //5 mins
    // let proposalCost = 0;
    // let daoAdminRole = "0xf591dda2e9b53c180cef2a1f29bc285ccc0649b7a0efc8de2ec0cfe024d46b96";
    // let daoInviteRole = "0xf8450c7be9c60a2b1311317b8f68d216b82a7116d8d7c927eb7554832e0cb05a";

    //ogre proposal
    // let proposalTitle = "Test Proposal";
    // let startTime;
    // let endTime;

    //ogre tokenized market
    let orderFee = 0;
    let feeRecipient;
    let minOrderLength = 60; //in seconds

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();

        //deploy ogre721 factory contract
        const OGRE721FactoryDeployer = await ethers.getContractFactory("OGRE721Factory");
        this.OGRE721Factory = await OGRE721FactoryDeployer.deploy();
        await this.OGRE721Factory.deployed();

        //deploy ogre treasury factory contract
        // const OGRETreasuryFactoryDeployer = await ethers.getContractFactory("OGRETreasuryFactory");
        // this.OGRETreasuryFactory = await OGRETreasuryFactoryDeployer.deploy();
        // await this.OGRETreasuryFactory.deployed();

        //deploy ogre treasury contract
        let OGRETreasuryDeployer = await ethers.getContractFactory("OGRETreasury");
        this.OGRETreasury = await OGRETreasuryDeployer.deploy(userA.address);
        await this.OGRETreasury.deployed();
    });

    beforeEach(async function () {
        //deploy OGRE721 contract
        let OGRE721Deployer = await ethers.getContractFactory("OGRE721");
        this.OGRE721 = await OGRE721Deployer.deploy(name, symbol, userA.address);
        await this.OGRE721.deployed();

        //mint nfts to userA
        let count = 10;
        for (let i = 0; i < count; i++) {
            await this.OGRE721.mint(userA.address, i);
        }

        //deploy OGRE20 contract
        let OGRE20Deployer = await ethers.getContractFactory("OGRE20");
        this.OGRE20 = await OGRE20Deployer.deploy(name, symbol, userA.address);
        await this.OGRE20.deployed();

        //mint tokens to userB
        let amount = 100;
        await this.OGRE20.mint(userB.address, amount);
    });

    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy OGRETokenizedMarket contract", async function () {
        let OGRETokenizedMarketDeployer = await ethers.getContractFactory("OGRETokenizedMarket");
        this.OGRETokenizedMarket = await OGRETokenizedMarketDeployer.deploy(this.OGRE721Factory.address, this.OGRETreasury.address);
        await this.OGRETokenizedMarket.deployed();

        listingTokenContractAddress = await this.OGRETokenizedMarket.listingTokenContractAddress();
        fulfillmentTokenContractAddress = await this.OGRETokenizedMarket.fulfillmentTokenContractAddress();

        expect(listingTokenContractAddress).to.not.equal(ethers.constants.AddressZero);
        expect(fulfillmentTokenContractAddress).to.not.equal(ethers.constants.AddressZero);

        //attach new token contracts to state
        let OGRE721Deployer = await ethers.getContractFactory("OGRE721");
        this.ListingTokenContract = OGRE721Deployer.attach(listingTokenContractAddress);
        this.FulfillmentTokenContract = OGRE721Deployer.attach(fulfillmentTokenContractAddress);

        expect(await this.ListingTokenContract.owner()).to.equal(this.OGRETokenizedMarket.address);
        expect(await this.FulfillmentTokenContract.owner()).to.equal(this.OGRETokenizedMarket.address);
    });

    it("should create new tokenized order", async function () {
        let orderType = 2; //ERC721_FOR_ERC20
        let tokenId = 1;
        let amount = 10;
        let orderDuration = 600;
        let offer = {
            itemType: 1, //ERC721
            contractAddress: this.OGRE721.address,
            amountOrTokenId: tokenId
        }
        let request = {
            itemType: 0, //ERC20
            contractAddress: this.OGRE20.address,
            amountOrTokenId: amount
        }

        //approve token id for market
        await this.OGRE721.approve(this.OGRETokenizedMarket.address, tokenId);

        const blockNum = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNum);
        const expiration = block.timestamp + orderDuration;

        //create tokenized order
        let createOrderTrx = await this.OGRETokenizedMarket.createTokenizedOrder(orderType, offer, request, expiration);
        
        let createOrderReceipt = await createOrderTrx.wait();
        expect(createOrderReceipt.events[3].event).to.equal('TokenizedOrderCreated');
        expect(createOrderReceipt.events[3].args['orderType']).to.equal(orderType);
        expect(createOrderReceipt.events[3].args['offer'].itemType).to.equal(offer.itemType);
        expect(createOrderReceipt.events[3].args['offer'].contractAddress).to.equal(offer.contractAddress);
        expect(createOrderReceipt.events[3].args['offer'].amountOrTokenId).to.equal(offer.amountOrTokenId);
        expect(createOrderReceipt.events[3].args['request'].itemType).to.equal(request.itemType);
        expect(createOrderReceipt.events[3].args['request'].contractAddress).to.equal(request.contractAddress);
        expect(createOrderReceipt.events[3].args['request'].amountOrTokenId).to.equal(request.amountOrTokenId);
        expect(createOrderReceipt.events[3].args['expiration']).to.equal(expiration);
        expect(createOrderReceipt.events[3].args['creator']).to.equal(userA.address);
        expect(createOrderReceipt.events[3].args['listingTokenId']).to.equal(1);

        let listing = await this.OGRETokenizedMarket.listings(1);
        expect(listing["orderType"]).to.equal(orderType);
        expect(listing["offered"].itemType).to.equal(offer.itemType);
        expect(listing["offered"].contractAddress).to.equal(offer.contractAddress);
        expect(listing["offered"].amountOrTokenId).to.equal(offer.amountOrTokenId);
        expect(listing["requested"].itemType).to.equal(request.itemType);
        expect(listing["requested"].contractAddress).to.equal(request.contractAddress);
        expect(listing["requested"].amountOrTokenId).to.equal(request.amountOrTokenId);
        expect(listing["expiration"]).to.equal(expiration);
        expect(listing["fulfillmentTokenId"]).to.equal(0);

        // expect(listed).to.equal(orderHash);
    });

    it("should match tokenized order", async function () {
        let orderType = 2; //ERC721_FOR_ERC20
        let tokenId = 1;
        let amount = 10;
        let orderDuration = 10000;
        let offer = {
            itemType: 1, //ERC721
            contractAddress: this.OGRE721.address,
            amountOrTokenId: tokenId
        }
        let request = {
            itemType: 0, //ERC20
            contractAddress: this.OGRE20.address,
            amountOrTokenId: amount
        }

        //approve token id for market
        await this.OGRE721.approve(this.OGRETokenizedMarket.address, tokenId);

        const blockNum = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNum);
        const expiration = block.timestamp + orderDuration;

        //create tokenized order
        let createOrderTrx = await this.OGRETokenizedMarket.createTokenizedOrder(orderType, offer, request, expiration);
        let createOrderReceipt = await createOrderTrx.wait();
        let listingATokenId = createOrderReceipt.events[3].args['listingTokenId'];

        //approve erc20 tokens for market
        this.OGRE20 = this.OGRE20.connect(userB);
        await this.OGRE20.approve(this.OGRETokenizedMarket.address, amount);

        //create matching tokenized order
        let matchingOrderType = 1;
        this.OGRETokenizedMarket = this.OGRETokenizedMarket.connect(userB);
        let createMatchingOrderTrx = await this.OGRETokenizedMarket.createTokenizedOrder(matchingOrderType, request, offer, expiration);
        let createMatchingOrderReceipt = await createMatchingOrderTrx.wait();
        let listingBTokenId = createMatchingOrderReceipt.events[3].args['listingTokenId'];

        //match committed orders
        let fulfillDuration = 600;
        this.OGRETokenizedMarket = this.OGRETokenizedMarket.connect(userC);
        let matchTrx = await this.OGRETokenizedMarket.matchTokenizedOrder(listingATokenId, listingBTokenId, fulfillDuration);
        let matchReceipt = await matchTrx.wait();
        let fulfillmentTokenId = matchReceipt.events[7].args['fulfillmentTokenId'];

        //fulfill order
        // let fulfillTrx = await this.OGRETokenizedMarket.fulfillTokenizedOrder(fulfillmentTokenId);
        // let fulfillReceipt = await fulfillTrx.wait();
        // console.log(fulfillReceipt.events);


    });

    // it("should ...", async function () {});

});