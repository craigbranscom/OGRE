const { task } = require("hardhat/config");

require("@nomicfoundation/hardhat-chai-matchers");
require("@nomiclabs/hardhat-ethers");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("balance", "Prints an the balance of an account")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs) => {
    const balance = await ethers.provider.getBalance(taskArgs.account);
    console.log(ethers.utils.formatEther(balance), "ETH");
});

task("fund", "Transfers 1 wei to recipient account", async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    const trx = {
      to: accounts[1].address,
      value: ethers.utils.parseEther('1'),
    };

    const trxHash = await accounts[0].sendTransaction(trx);
    console.log(trxHash);
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.17",
  networks: {
    hardhat: {
      mining: {
        auto: false,
        interval: [3000, 6000]
      }
    }
  }
};
