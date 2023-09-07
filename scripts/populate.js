const { ethers } = require("hardhat");
const hardhat = require("hardhat");

async function main() {
    //signers
    let userA;
    let userB;
    let userC;
    let addrs;

    //get signers
    [userA, userB, userC, ...addrs] = await ethers.getSigners();

    //---------- Deploy Factories ----------

    //deploy ogre 20 factory
    const OGRE20FactoryDeployer = await ethers.getContractFactory("OGRE20Factory");
    const OGRE20Factory = await OGRE20FactoryDeployer.deploy();
    await OGRE20Factory.deployed();
    console.log("OGRE20Factory deployed to:", OGRE20Factory.address);

    //deploy ogre nft factory 
    const OGRE721FactoryDeployer = await ethers.getContractFactory("OGRE721Factory");
    const OGRE721Factory = await OGRE721FactoryDeployer.deploy();
    await OGRE721Factory.deployed();
    console.log("OGRE721Factory deployed to:", OGRE721Factory.address);

    //deploy ogre dao factory
    const OGREDAOFactoryDeployer = await ethers.getContractFactory("OGREDAOFactory");
    const OGREDAOFactory = await OGREDAOFactoryDeployer.deploy();
    await OGREDAOFactory.deployed();
    console.log("OGREDAOFactory deployed to:", OGREDAOFactory.address);

    //deploy ogre proposal factory
    const OGREProposalFactoryDeployer = await ethers.getContractFactory("OGREProposalFactory");
    const OGREProposalFactory = await OGREProposalFactoryDeployer.deploy();
    await OGREProposalFactory.deployed();
    console.log("OGREProposalFactory deployed to:", OGREProposalFactory.address);

    //deploy ogre market factory
    const OGREMarketFactoryDeployer = await ethers.getContractFactory("OGREMarketFactory");
    const OGREMarketFactory = await OGREMarketFactoryDeployer.deploy();
    await OGREMarketFactory.deployed();
    console.log("OGREMarketFactory deployed to:", OGREMarketFactory.address);

    //---------- Produce Contracts ----------

    //produce ogre 20 contract
    let ogre20Name = "OGRE20 Test";
    let ogre20Symbol = "TEST20";
    let ogre20Owner = userA.address;

    let ogre20ProduceTrx = await OGRE20Factory.produceOGRE20(ogre20Name, ogre20Symbol, ogre20Owner);
    let ogre20ProduceReceipt = await ogre20ProduceTrx.wait();

    const OGRE20Deployer = await ethers.getContractFactory("OGRE20");
    let OGRE20 = OGRE20Deployer.attach(ogre20ProduceReceipt.events[2].args['contractAddress']);
    console.log("OGRE20 contract deployed to:", OGRE20.address)

    //produce ogre 721 contract
    let ogre721Name = "OGRE721 Test";
    let ogre721Symbol = "TEST721";
    let ogre721Owner = userA.address;

    let trx1 = await OGRE721Factory.produceOGRE721(ogre721Name, ogre721Symbol, ogre721Owner);
    let receipt1 = await trx1.wait();

    const OGRE721Deployer = await ethers.getContractFactory("OGRE721");
    let OGRE721 = OGRE721Deployer.attach(receipt1.events[2].args['contractAddress']);
    console.log("OGRE721 contract deployed to:", OGRE721.address)

    //produce ogre dao contract
    let daoName = "Test DAO";
    let daoMeta = "";
    let proposalCost = 0;
    let delay = 300;

    let trx2 = await OGREDAOFactory.produceOGREDAO(daoName, daoMeta, OGRE721.address, OGREProposalFactory.address, proposalCost, userA.address, delay);
    let receipt2 = await trx2.wait();

    const OGREDAODeployer = await ethers.getContractFactory("OGREDAO");
    let OGREDAO = OGREDAODeployer.attach(receipt2.events[4].args['contractAddress']);
    console.log("OGREDAO contract deployed to:", OGREDAO.address);

    //produce ogre market contract
    let orderFee = ethers.utils.parseEther("0.001");
    let mktTrx = await OGREMarketFactory.produceOGREMarket(OGREDAO.address, userA.address, orderFee, userA.address);
    let mktReceipt = await mktTrx.wait();

    const OGREMarketDeployer = await ethers.getContractFactory("OGREMarket");
    let OGREMarket = OGREMarketDeployer.attach(mktReceipt.events[4].args['contractAddress']);
    console.log("OGREMarket contract deployed to:", OGREMarket.address);

    //---------- Mint and Register NFTs ----------

    OGREDAO.connect(userA);
    OGRE721.connect(userA);

    //mint nfts to userA (starting at token id 0)
    let count = 10;
    for (let i = 0; i < count; i++) {
        await OGRE721.mint(userA.address, i);
        await OGREDAO.registerMember(i);
    }

    //---------- Create Proposal ----------

    //draft proposal
    let proposalTitle = "Test Proposal";
    let trx3 = await OGREDAO.draftProposal(proposalTitle);
    let receipt3 = await trx3.wait();

    const OGREProposalDeployer = await ethers.getContractFactory("OGREProposal");
    let OGREProposal = OGREProposalDeployer.attach(receipt3.events[4].args['proposal']);
    console.log("OGREProposal contract deployed to:", OGREProposal.address);

    //start proposal
    const prevBlockNum = await ethers.provider.getBlockNumber();
    const prevBlock = await ethers.provider.getBlock(prevBlockNum);
    const prevTimestamp = prevBlock.timestamp;

    let votePeriodLength = 300; //in seconds
    let startTime = prevTimestamp + 1; //add 1 since start time must be in future
    let endTime = startTime + votePeriodLength;
    await OGREProposal.setVotingPeriod(startTime, endTime);

    //---------- Cast Votes on Proposal ----------

    //cast votes
    let voteCount = 10;
    for (let i = 0; i < voteCount; i++) {
        await OGREProposal.castVote(i, 1); //yes votes
    }
    //advance network time
    // await network.provider.send("evm_setNextBlockTimestamp", [endTime + 1]); //add one to go past end time
    // await network.provider.send("evm_mine") // this one will have end time as its timestamp

    //---------- Create Asks and Bids ----------

    let tokenId = 1;
    let amount = 10;

    //mint erc20 tokens to userB
    OGRE20 = OGRE20.connect(userA);
    await OGRE20.mint(userB.address, 100);

    //approve erc721 token to OGREMarket
    OGRE721 = OGRE721.connect(userA);
    await OGRE721.approve(OGREMarket.address, tokenId);

    //approve erc20 allowance to OGREMarket
    OGRE20 = OGRE20.connect(userB);
    await OGRE20.approve(OGREMarket.address, 100);

    //add erc20 and erc721 contracts to allowlist
    OGREMarket = OGREMarket.connect(userA);
    await OGREMarket.setContractAllowed(OGRE20.address, true);
    await OGREMarket.setContractAllowed(OGRE721.address, true);

    //create ask
    // OGREMarket = OGREMarket.connect(userA);
    // await OGREMarket.createAsk(OGRE721.address, tokenId, OGRE20.address, amount, {value: orderFee});

    //create bids
    // OGREMarket = OGREMarket.connect(userB);
    // let bidCount = 10;
    // for  (let i = 0; i < bidCount; i++) {
    //     await OGREMarket.createBid(OGRE721.address, i + 1, OGRE20.address, amount, {value: orderFee});
    // }
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });