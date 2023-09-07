const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GreatExchange Tests", function () {
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

    //great exchange contract
    let ERC20_ENUM = 0;
    let ERC721_ENUM = 1;
    let orderFee = 0;
    let feeRecipient;
    let minOrderDuration = 60; //in seconds

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();

        //deploy ogre721 factory contract
        const OGRE721FactoryDeployer = await ethers.getContractFactory("OGRE721Factory");
        this.OGRE721Factory = await OGRE721FactoryDeployer.deploy();
        await this.OGRE721Factory.deployed();

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

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    //========== Contract Deployment Tests ==========

    it("should deploy GreatExchange contract", async function () {
        feeRecipient = userA.address;

        let GreatExchangeDeployer = await ethers.getContractFactory("GreatExchange");
        this.GreatExchange = await GreatExchangeDeployer.deploy(userA.address, orderFee, feeRecipient, minOrderDuration);
        await this.GreatExchange.deployed();

        let feeRecipientRes = await this.GreatExchange.feeRecipient();
        let orderFeeRes = await this.GreatExchange.orderFee();
        let minOrderDurationRes = await this.GreatExchange.minOrderDuration();

        expect(feeRecipientRes).to.equal(feeRecipient);
        expect(orderFeeRes).to.equal(orderFee);
        expect(minOrderDurationRes).to.equal(minOrderDuration);
    });

    //========== Utility Function Tests ==========

    it("should compute order hash", async function () {
        let offeredTokenId = 1;
        let requestedTokenAmount = 10;
        let offered = {
            contractType: ERC721_ENUM,
            contractAddress: this.OGRE721.address,
            amountOrTokenId: offeredTokenId
        };
        let requested = {
            contractType: ERC20_ENUM,
            contractAddress: this.OGRE20.address,
            amountOrTokenId: requestedTokenAmount
        };

        let res = await this.GreatExchange.computeOrderHash(offered, requested);
    });

    //========== Single Order Function Tests ==========

    it("should create single order", async function () {
        let offeredTokenId = 1;
        let requestedTokenAmount = 10;
        let offered = {
            contractType: ERC721_ENUM,
            contractAddress: this.OGRE721.address,
            amountOrTokenId: offeredTokenId
        };
        let requested = {
            contractType: ERC20_ENUM,
            contractAddress: this.OGRE20.address,
            amountOrTokenId: requestedTokenAmount
        };
        let recipient = ethers.constants.AddressZero;
        let orderDuration = 600;
        const blockNum = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNum);
        const expiration = block.timestamp + orderDuration;
        let order = {
            offered: offered,
            requested: requested,
            creator: userA.address,
            recipient: recipient,
            expiration: expiration
        };

        //compute order hash
        let orderHash = await this.GreatExchange.computeOrderHash(offered, requested);

        //approve exchange address
        let approveTrx = await this.OGRE721.approve(this.GreatExchange.address, offeredTokenId);

        //create order
        let createOrderTrx = await this.GreatExchange.createOrder(order);

        let createOrderReceipt = await createOrderTrx.wait();
        expect(createOrderReceipt.events[0].event).to.equal('OrderCreated');
        expect(createOrderReceipt.events[0].args['orderHash']).to.equal(orderHash);
        expect(createOrderReceipt.events[0].args['offered'].contractType).to.equal(offered.contractType);
        expect(createOrderReceipt.events[0].args['offered'].contractAddress).to.equal(offered.contractAddress);
        expect(createOrderReceipt.events[0].args['offered'].amountOrTokenId).to.equal(offered.amountOrTokenId);
        expect(createOrderReceipt.events[0].args['requested'].contractType).to.equal(requested.contractType);
        expect(createOrderReceipt.events[0].args['requested'].contractAddress).to.equal(requested.contractAddress);
        expect(createOrderReceipt.events[0].args['requested'].amountOrTokenId).to.equal(requested.amountOrTokenId);
        expect(createOrderReceipt.events[0].args['creator']).to.equal(userA.address);
        expect(createOrderReceipt.events[0].args['recipient']).to.equal(recipient);
        expect(createOrderReceipt.events[0].args['expiration']).to.equal(expiration);

        let orderRes = await this.GreatExchange.orderbook(orderHash);
        expect(orderRes["offered"].contractType).to.equal(offered.contractType);
        expect(orderRes["offered"].contractAddress).to.equal(offered.contractAddress);
        expect(orderRes["offered"].amountOrTokenId).to.equal(offered.amountOrTokenId);
        expect(orderRes["requested"].contractType).to.equal(requested.contractType);
        expect(orderRes["requested"].contractAddress).to.equal(requested.contractAddress);
        expect(orderRes["requested"].amountOrTokenId).to.equal(requested.amountOrTokenId);
        expect(orderRes["creator"]).to.equal(userA.address);
        expect(orderRes["recipient"]).to.equal(recipient);
        expect(orderRes["expiration"]).to.equal(expiration);
    });

    it("should check if single order exists", async function () {
        let offeredTokenId = 1;
        let requestedTokenAmount = 10;
        let offered = {
            contractType: ERC721_ENUM,
            contractAddress: this.OGRE721.address,
            amountOrTokenId: offeredTokenId
        };
        let requested = {
            contractType: ERC20_ENUM,
            contractAddress: this.OGRE20.address,
            amountOrTokenId: requestedTokenAmount
        };

        //compute order hash
        let orderHash = await this.GreatExchange.computeOrderHash(offered, requested);

        expect(await this.GreatExchange.orderExists(orderHash)).to.equal(true);
    });

    it("should fulfill single order", async function () {
        let offeredTokenId = 1;
        let requestedTokenAmount = 10;
        let offered = {
            contractType: ERC721_ENUM,
            contractAddress: this.OGRE721.address,
            amountOrTokenId: offeredTokenId
        };
        let requested = {
            contractType: ERC20_ENUM,
            contractAddress: this.OGRE20.address,
            amountOrTokenId: requestedTokenAmount
        };
        let recipient = ethers.constants.AddressZero;
        let orderDuration = 600;
        const blockNum = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNum);
        const expiration = block.timestamp + orderDuration;

        //compute order hash
        let orderHash = await this.GreatExchange.computeOrderHash(offered, requested);

        //approve exchange address
        this.OGRE20 = this.OGRE20.connect(userB);
        let approveTrx = await this.OGRE20.approve(this.GreatExchange.address, requestedTokenAmount);

        //create order
        this.GreatExchange = this.GreatExchange.connect(userB);
        let fulfillOrderTrx = await this.GreatExchange.fulfillOrder(orderHash);

        let fulfillOrderReceipt = await fulfillOrderTrx.wait();
        expect(fulfillOrderReceipt.events[3].event).to.equal('OrderFulfilled');
        expect(fulfillOrderReceipt.events[3].args['orderHash']).to.equal(orderHash);
        expect(fulfillOrderReceipt.events[3].args['fulfilledBy']).to.equal(userB.address);

        let orderRes = await this.GreatExchange.orderbook(orderHash);
        expect(orderRes["offered"].contractType).to.equal(0);
        expect(orderRes["offered"].contractAddress).to.equal(ethers.constants.AddressZero);
        expect(orderRes["offered"].amountOrTokenId).to.equal(0);
        expect(orderRes["requested"].contractType).to.equal(0);
        expect(orderRes["requested"].contractAddress).to.equal(ethers.constants.AddressZero);
        expect(orderRes["requested"].amountOrTokenId).to.equal(0);
        expect(orderRes["creator"]).to.equal(ethers.constants.AddressZero);
        expect(orderRes["recipient"]).to.equal(ethers.constants.AddressZero);
        expect(orderRes["expiration"]).to.equal(0);
    });

    //========== Batch Order Function Tests ==========

    it("should create batch order", async function () {
        let offered1 = {
            contractType: 1,
            contractAddress: this.OGRE721.address,
            amountOrTokenId: 2
        };
        let requested1 = {
            contractType: 0,
            contractAddress: this.OGRE20.address,
            amountOrTokenId: 20
        };
        let offered2 = {
            contractType: 1,
            contractAddress: this.OGRE721.address,
            amountOrTokenId: 3
        };
        let requested2 = {
            contractType: 0,
            contractAddress: this.OGRE20.address,
            amountOrTokenId: 25
        };
        let recipient = ethers.constants.AddressZero;
        let orderDuration = 600;
        const blockNum = await ethers.provider.getBlockNumber();
        const block = await ethers.provider.getBlock(blockNum);
        const expiration = block.timestamp + orderDuration;
        let order1 = {
            offered: offered1,
            requested: requested1,
            creator: userA.address,
            recipient: recipient,
            expiration: expiration
        };
        let order2 = {
            offered: offered2,
            requested: requested2,
            creator: userA.address,
            recipient: recipient,
            expiration: expiration
        };

        //compute order hash
        let orderHash1 = await this.GreatExchange.computeOrderHash(offered1, requested1);
        let orderHash2 = await this.GreatExchange.computeOrderHash(offered2, requested2);

        //approve exchange address
        let approveTrx1 = await this.OGRE721.approve(this.GreatExchange.address, 2);
        let approveTrx2 = await this.OGRE721.approve(this.GreatExchange.address, 3);

        //create batch order
        this.GreatExchange = this.GreatExchange.connect(userA);
        let createOrderBatchTrx = await this.GreatExchange.createOrderBatch([order1, order2]);

        let createOrderBatchReceipt = await createOrderBatchTrx.wait();
        expect(createOrderBatchReceipt.events[0].event).to.equal('OrderCreated');
        expect(createOrderBatchReceipt.events[0].args['orderHash']).to.equal(orderHash1);
        expect(createOrderBatchReceipt.events[0].args['offered'].contractType).to.equal(offered1.contractType);
        expect(createOrderBatchReceipt.events[0].args['offered'].contractAddress).to.equal(offered1.contractAddress);
        expect(createOrderBatchReceipt.events[0].args['offered'].amountOrTokenId).to.equal(offered1.amountOrTokenId);
        expect(createOrderBatchReceipt.events[0].args['requested'].contractType).to.equal(requested1.contractType);
        expect(createOrderBatchReceipt.events[0].args['requested'].contractAddress).to.equal(requested1.contractAddress);
        expect(createOrderBatchReceipt.events[0].args['requested'].amountOrTokenId).to.equal(requested1.amountOrTokenId);
        expect(createOrderBatchReceipt.events[0].args['creator']).to.equal(userA.address);
        expect(createOrderBatchReceipt.events[0].args['recipient']).to.equal(recipient);
        expect(createOrderBatchReceipt.events[0].args['expiration']).to.equal(expiration);
        
        expect(createOrderBatchReceipt.events[1].event).to.equal('OrderCreated');
        expect(createOrderBatchReceipt.events[1].args['orderHash']).to.equal(orderHash2);
        expect(createOrderBatchReceipt.events[1].args['offered'].contractType).to.equal(offered2.contractType);
        expect(createOrderBatchReceipt.events[1].args['offered'].contractAddress).to.equal(offered2.contractAddress);
        expect(createOrderBatchReceipt.events[1].args['offered'].amountOrTokenId).to.equal(offered2.amountOrTokenId);
        expect(createOrderBatchReceipt.events[1].args['requested'].contractType).to.equal(requested2.contractType);
        expect(createOrderBatchReceipt.events[1].args['requested'].contractAddress).to.equal(requested2.contractAddress);
        expect(createOrderBatchReceipt.events[1].args['requested'].amountOrTokenId).to.equal(requested2.amountOrTokenId);
        expect(createOrderBatchReceipt.events[1].args['creator']).to.equal(userA.address);
        expect(createOrderBatchReceipt.events[1].args['recipient']).to.equal(recipient);
        expect(createOrderBatchReceipt.events[1].args['expiration']).to.equal(expiration);

        let orderRes1 = await this.GreatExchange.orderbook(orderHash1);
        expect(orderRes1["offered"].contractType).to.equal(offered1.contractType);
        expect(orderRes1["offered"].contractAddress).to.equal(offered1.contractAddress);
        expect(orderRes1["offered"].amountOrTokenId).to.equal(offered1.amountOrTokenId);
        expect(orderRes1["requested"].contractType).to.equal(requested1.contractType);
        expect(orderRes1["requested"].contractAddress).to.equal(requested1.contractAddress);
        expect(orderRes1["requested"].amountOrTokenId).to.equal(requested1.amountOrTokenId);
        expect(orderRes1["creator"]).to.equal(userA.address);
        expect(orderRes1["recipient"]).to.equal(recipient);
        expect(orderRes1["expiration"]).to.equal(expiration);

        let orderRes2 = await this.GreatExchange.orderbook(orderHash2);
        expect(orderRes2["offered"].contractType).to.equal(offered2.contractType);
        expect(orderRes2["offered"].contractAddress).to.equal(offered2.contractAddress);
        expect(orderRes2["offered"].amountOrTokenId).to.equal(offered2.amountOrTokenId);
        expect(orderRes2["requested"].contractType).to.equal(requested2.contractType);
        expect(orderRes2["requested"].contractAddress).to.equal(requested2.contractAddress);
        expect(orderRes2["requested"].amountOrTokenId).to.equal(requested2.amountOrTokenId);
        expect(orderRes2["creator"]).to.equal(userA.address);
        expect(orderRes2["recipient"]).to.equal(recipient);
        expect(orderRes2["expiration"]).to.equal(expiration);
    });

    // it("should ...", async function () {});

});