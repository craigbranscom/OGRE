# Open Governance Referendum Engine

A smart contract suite for actionable governance within NFT communities.

# TODO

* access control. onlySelf?
* voting power
* delegations?
* remove registering?
* add memberSet? [] = *, [1,3,5,7,9,...]
* can add/remove members from set after creation?
* updateDelay function?
* updateProposalFactory function?
* add treasury contract?

# Setup

## Prerequisites

* npm
* hardhat

`npm install`

## Compile

`npx hardhat compile`

## Build Go Bindings

solc --abi contracts/OGREDAO.sol
solc --bin contracts/OGREDAO.sol
abigen --bin=Store_sol_Store.bin --abi=Store_sol_Store.abi --pkg=dao --out=go/OGREDAO.go

`docker run -v ~/GitHub/OGRE/:/sources ethereum/solc:0.8.17 -o sources/go --abi --bin /sources/contracts/OGREDAO.sol`

`abigen --abi=./output/OGREDAO.abi --pkg=dao --out=go/OGREDAO.go`

## Run Hardhat Tasks and Scripts

`npx hardhat balance --account 0x...`

`npx hardhat run --network localhost scripts/populate.js`

## Deploy Contract Factories

The `factories` folder contains simple factory contracts that deploy copies of their respective contracts. The `OGREDAOFactory` produces `OGREDAOs`, `OGRE721Factory` produces `OGRE721s`, etc.

Run `npx hardhat run scripts/deployFactories.js` to deploy all factory contracts. This only needs to be done once per network, per factory version. New factory contracts should be deployed that produce updated versions of their respective contracts.

For example, if the `OGREProposal` contract is updated from v1.0 to v1.1 then a new `OGREProposalFactory` contract should also be deployed that will produce the new v1.1 proposals. Of course older factories will always remain on chain, so DAOs can choose which factory will produce a given proposal.

## Create a DAO

To create a new DAO call the `produceOGREDAO` function on the `OGREDAOFactory` contract. This will deploy a new DAO contract where membership is controlled by an existing ERC721 contract. New ERC721 contracts can be deployed by calling `produceOGRE721` on the `OGRE721Factory` contract. Note that OGRE DAOs do not specifically need OGRE NFTs to operate - any valid ERC721 contract is supported.

### Configure DAO

Once deployed, the DAO owner account should configure the DAO by updating the vote thresholds and vote period.

* The `votePeriod` is the minimum amount of time (in seconds) that a proposal must be open for voting in order to be acknowledged by the dao. Proposals that run voting periods less than the minimum will fail to be evaluated by the DAO.
* The `supportThreshold` is a value representing a percent of all votes that must be YES in order to pass. (450 = 4.50%)
* The `quorumthreshold` is a value representing a percent of all members that must participate on the proposal to pass. (450 = 4.50%)

Note that both `supportThreshold` and `quorumThreshold` checks must pass in order to consider the proposal PASSED. 

## Draft a Proposal

DAO members can draft new proposals for the DAO, which can include an array of Actions that will be executed by the DAO contract if the proposal passes.

### Configure Proposal



# Contracts Breakdown

## Base Contracts

| Contract Name    | Description      |
| ---------------- | ---------------- |
| OGREDAO          | DAO contract linked to an existing ERC721 contract for membership. Can create Proposals and SubDAOS. |
| OGRE721          | Standard ERC721 contract with mint and burn functions enabled. Contract is Ownable and Pausable. |
| OGREProposal     | Proposal contract. Controlled by creator (DAO member). If actionable can execute decisions within the org within role scope. |

## Abstract Contracts

| Contract Name    | Description      |
| ---------------- | ---------------- |
| ActionHopper     | Contract for queuing multiple transactions to be executed. Inherited by OGREDAO contract. |
| ERC721Receivable | Enables inheriting contracts to send and receive ERC721 tokens. Implements onERC721Received function. |
| OGREFactory      | Base factory contract. |

## Factory Contracts

| Contract Name       | Description      |
| ------------------- | ---------------- |
| OGREDAOFactory      | Produces OGREDAO contracts for caller. |
| OGRE721Factory      | Produces OGRE721 contracts for caller. |
| OGREProposalFactory | Produces OGREProposal contracts for caller. |
