// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

library Constants {

    //OGREDAO roles
    bytes32 public constant DAO_ADMIN = keccak256("DAO_ADMIN"); //0xf591dda2e9b53c180cef2a1f29bc285ccc0649b7a0efc8de2ec0cfe024d46b96
    bytes32 public constant DAO_INVITE = keccak256("DAO_INVITE"); //0xf8450c7be9c60a2b1311317b8f68d216b82a7116d8d7c927eb7554832e0cb05a

    //OGREMarket roles
    bytes32 public constant MARKET_ADMIN = keccak256("MARKET_ADMIN"); //

    //OGREOptions roles
    bytes32 public constant OPTIONS_ADMIN = keccak256("OPTIONS_ADMIN"); //

    //OGREProposal roles
    bytes32 public constant PROPOSAL_ADMIN = keccak256("PROPOSAL_ADMIN"); //0x49b9cd9e19b40e24eab999bc6ebb1c3f06990f570acd2c1074f2593bcfdb93a1

    //OGRETreasury roles
    bytes32 public constant TREASURY_ADMIN = keccak256("TREASURY_ADMIN"); //0x27f406f19fd1b378cfb619bc553f0cd86d17e85e38ecad46997fb68ad17b7307

}