const hardhat = require("hardhat");

async function main() {
    //deploy ogre 20 factory
    const OGRE20FactoryDeployer = await ethers.getContractFactory("OGRE20Factory");
    const ogre20 = await OGRE20FactoryDeployer.deploy();
    await ogre20.deployed();
    console.log("OGRE721Factory deployed to:", ogre20.address);

    //deploy ogre 721 factory 
    const OGRE721FactoryDeployer = await ethers.getContractFactory("OGRE721Factory");
    const ogre721 = await OGRE721FactoryDeployer.deploy();
    await ogre721.deployed();
    console.log("OGRE721Factory deployed to:", ogre721.address);

    //deploy ogre dao factory
    const OGREDAOFactoryDeployer = await ethers.getContractFactory("OGREDAOFactory");
    const dao = await OGREDAOFactoryDeployer.deploy();
    await dao.deployed();
    console.log("OGREDAOFactory deployed to:", dao.address);

    //deploy ogre proposal factory
    const OGREProposalFactoryDeployer = await ethers.getContractFactory("OGREProposalFactory");
    const proposal = await OGREProposalFactoryDeployer.deploy();
    await proposal.deployed();
    console.log("OGREProposalFactory deployed to:", proposal.address);

    //deploy ogre market factory
    const OGREMarketFactoryDeployer = await ethers.getContractFactory("OGREMarketFactory");
    const mkt = await OGREMarketFactoryDeployer.deploy();
    await mkt.deployed();
    console.log("OGREMarketFactory deployed to:", mkt.address);
}
  
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });