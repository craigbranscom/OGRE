const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ActionHopper Tests", function () {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //erc721
    let name = "Test NFTs";
    let symbol = "TEST";
    let maxSupply = 1;
    let owner;

    //stub settings
    let delay = 10; //in seconds

    async function advanceTimeByDelay() {
        const prevBlockNum = await ethers.provider.getBlockNumber();
        const prevBlock = await ethers.provider.getBlock(prevBlockNum);
        const prevTimestamp = prevBlock.timestamp;

        endTime = prevTimestamp + delay;

        //advance network time
        await network.provider.send("evm_setNextBlockTimestamp", [endTime + 1]); //add one to go past end time
        await network.provider.send("evm_mine") // this one will have end time as its timestamp
    }

    before(async function () {
        //get signers
        [userA, userB, userC, ...addrs] = await ethers.getSigners();

        //deploy OGRE721 contract
        let OGRE721Deployer = await ethers.getContractFactory("OGRE721");
        owner = userA.address;
        this.OGRE721 = await OGRE721Deployer.deploy(name, symbol, owner);
        await this.OGRE721.deployed();
    });

    // beforeEach(async function () {});
    // after(async function () {});
    // afterEach(async function () {});

    it("should deploy contract inheriting from ActionHopper - StubActionHopper", async function () {
        let StubActionHopperDeployer = await ethers.getContractFactory("StubActionHopper");
        this.StubActionHopper = await StubActionHopperDeployer.deploy(delay);
        await this.StubActionHopper.deployed();
    });

    it("should fail to execute action - ActionNotLoaded", async function () {
        let target = userA.address;
        let value = 1;
        let sig = "";
        let data = "0x";

        await expect(
            this.StubActionHopper.executeAction(target, value, sig, data, 0)
        ).to.be.revertedWithCustomError(
            this.StubActionHopper,
            "ActionNotLoaded"
        );
    });

    it("should load an action", async function () {
        let target = userA.address;
        let value = 1;
        let sig = "";
        let data = "0x";

        let trx = await this.StubActionHopper.loadAction(target, value, sig, data);
        let receipt = await trx.wait();

        expect(receipt.events[0].event).to.equal('ActionLoaded');
        // expect(receipt.events[0].args['trxHash']).to.equal(userB.address);
        expect(receipt.events[0].args['target']).to.equal(target);
        expect(receipt.events[0].args['value']).to.equal(value);
        expect(receipt.events[0].args['sig']).to.equal(sig);
        expect(receipt.events[0].args['data']).to.equal(data);
        // expect(receipt.events[0].args['ready']).to.equal(this.OGRE721.address);

        this.trxHash = receipt.events[0].args['trxHash'];
        this.ready = receipt.events[0].args['ready'];
    });

    it("should fail to execute loaded action - ActionNotReady", async function () {
        let target = userA.address;
        let value = 1;
        let sig = "";
        let data = "0x";

        await expect(
            this.StubActionHopper.executeAction(target, value, sig, data, this.ready)
        ).to.be.revertedWithCustomError(
            this.StubActionHopper,
            "ActionNotReady"
        );
    });

    it("should execute readied action", async function () {
        //wait until ready time
        advanceTimeByDelay();

        //fund stub address to pay for wei transfer
        let amount = "0.0000000001";
        const tx = {
            to: this.StubActionHopper.address,
            value: ethers.utils.parseEther(amount),
        }
        await userA.sendTransaction(tx);
        
        let target = userA.address;
        let value = 1;
        let sig = "";
        let data = "0x";

        //execute readied action
        let trx = await this.StubActionHopper.executeAction(target, value, sig, data, this.ready);
        let receipt = await trx.wait();

        expect(receipt.events[0].event).to.equal('ActionExecuted');
        // expect(receipt.events[0].args['trxHash']).to.equal(userB.address);
        // expect(receipt.events[0].args['target']).to.equal(target);
        // expect(receipt.events[0].args['value']).to.equal(value);
        // expect(receipt.events[0].args['sig']).to.equal(sig);
        // expect(receipt.events[0].args['data']).to.equal(data);
        // expect(receipt.events[0].args['ready']).to.equal(this.OGRE721.address);
    });

    it("should load, ready, and execute action - ERC721::transferFrom", async function () {
        let tokenId = 0;
        let target = this.OGRE721.address;
        let value = 0;
        let sig = "transferFrom(address,address,uint256)";
        let data = ethers.utils.defaultAbiCoder.encode(["address", "address", "uint256"], [this.StubActionHopper.address, userB.address, 0]);

        //mint nft to stub for transferFrom action
        await this.OGRE721.mint(userA.address, 0);
        await this.OGRE721.transferFrom(userA.address, this.StubActionHopper.address, tokenId);
        expect(await this.OGRE721.ownerOf(tokenId)).to.equal(this.StubActionHopper.address);

        //load action
        let loadTrx = await this.StubActionHopper.loadAction(target, value, sig, data);
        let loadReceipt = await loadTrx.wait();

        expect(loadReceipt.events[0].event).to.equal('ActionLoaded');
        // expect(loadReceipt.events[0].args['trxHash']).to.equal(userB.address);
        expect(loadReceipt.events[0].args['target']).to.equal(target);
        expect(loadReceipt.events[0].args['value']).to.equal(value);
        expect(loadReceipt.events[0].args['sig']).to.equal(sig);
        expect(loadReceipt.events[0].args['data']).to.equal(data);
        // expect(loadReceipt.events[0].args['ready']).to.equal(this.OGRE721.address);

        this.trxHash = loadReceipt.events[0].args['trxHash'];
        this.ready = loadReceipt.events[0].args['ready'];

        //wait until ready time
        advanceTimeByDelay();
        advanceTimeByDelay();
        advanceTimeByDelay();
        const prevBlockNum = await ethers.provider.getBlockNumber();

        //execute readied action
        let execTrx = await this.StubActionHopper.executeAction(target, value, sig, data, this.ready);
        let execReceipt = await execTrx.wait();

        expect(execReceipt.events[0].event).to.equal('ActionExecuted');

        expect(await this.OGRE721.ownerOf(tokenId)).to.equal(userB.address);
    });

    it("should fail to execute action - ActionExecutionFailed", async function () {
        //action should fail
        let tokenId = 1;
        let target = this.OGRE721.address;
        let value = 0;
        let sig = "transferFrom(address,address,uint256)";
        let data = ethers.utils.defaultAbiCoder.encode(["address", "address", "uint256"], [this.StubActionHopper.address, userB.address, 0]);

        //mint nft to stub for transferFrom action
        await this.OGRE721.mint(userA.address, tokenId);
        await this.OGRE721.transferFrom(userA.address, this.StubActionHopper.address, tokenId);
        expect(await this.OGRE721.ownerOf(tokenId)).to.equal(this.StubActionHopper.address);

        //load action
        let loadTrx = await this.StubActionHopper.loadAction(target, value, sig, data);
        let loadReceipt = await loadTrx.wait();

        expect(loadReceipt.events[0].event).to.equal('ActionLoaded');
        // expect(loadReceipt.events[0].args['trxHash']).to.equal(userB.address);
        expect(loadReceipt.events[0].args['target']).to.equal(target);
        expect(loadReceipt.events[0].args['value']).to.equal(value);
        expect(loadReceipt.events[0].args['sig']).to.equal(sig);
        expect(loadReceipt.events[0].args['data']).to.equal(data);
        // expect(loadReceipt.events[0].args['ready']).to.equal(this.OGRE721.address);

        this.trxHash = loadReceipt.events[0].args['trxHash'];
        this.ready = loadReceipt.events[0].args['ready'];

        //wait until ready time
        advanceTimeByDelay();
        advanceTimeByDelay();
        advanceTimeByDelay();
        const prevBlockNum = await ethers.provider.getBlockNumber();

        //attempt to execute readied action
        await expect(
            this.StubActionHopper.executeAction(target, value, sig, data, this.ready)
        ).to.be.revertedWithCustomError(
            this.StubActionHopper,
            "ActionExecutionFailed"
        );

        expect(await this.OGRE721.ownerOf(tokenId)).to.equal(this.StubActionHopper.address);
    });

    // it("should ...", async function () {});

});