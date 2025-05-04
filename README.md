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

* Foundry (forge, cast, anvil)
* Git

## Installation

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone the repository:
```bash
git clone https://github.com/craigbranscom/OGRE.git
cd OGRE
```

3. Install dependencies:
```bash
forge install
```

## Compile

```bash
forge build
```

## Test

```bash
forge test
```

## Deploy Contract Factories

The `factories` folder contains simple factory contracts that deploy copies of their respective contracts. The `OGREDAOFactory` produces `OGREDAOs`, `OGRE721Factory` produces `OGRE721s`, etc.

To deploy a factory contract:

```bash
forge create src/factories/OGREDAOFactory.sol:OGREDAOFactory --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

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
