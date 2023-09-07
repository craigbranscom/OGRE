const { BN, constants, expectEvent, expectRevert, balance } = require("@openzeppelin/test-helpers");
const { web3 } = require("@openzeppelin/test-helpers/src/setup");

const OGRETreasuryContract = artifacts.require("OGRETreasury");

contract("NativeReceivable Unit Tests", async accounts => {
    const [deployer, userA, userB, userC] = accounts;
    const depositAmount = 1;

    let receivableAddress = "";

    before(async () => {
        //initialize arrays
        this.contracts = [];
    });

    it("Can deploy NativeReceivable contract", async () => {
        this.contracts[0] = await OGRETreasuryContract.new({from: deployer});
        receivableAddress = this.contracts[0].address;
    });

    it("Can deposit native tokens", async () => {
        //send transaction
        const t1 = await this.contracts[0].depositNative({from: userA, value: depositAmount});

        //TODO: check balance
    });

});