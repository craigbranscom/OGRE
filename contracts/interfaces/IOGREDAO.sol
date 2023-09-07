// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/**
 * @notice OGRE DAO interface definition
 */
interface IOGREDAO {
    function proposalFactoryAddress() external view returns (address);
    function nftAddress() external view returns (address);

    function daoName() external view returns (string memory);
    function daoMetadata() external view returns (string memory);

    function quorumThreshold() external view returns (uint256);
    function supportThreshold() external view returns (uint256);
    function minVotePeriod() external view returns (uint256);

    function memberCount() external view returns (uint256);
    function getMemberStatus(uint256 tokenId) external view returns (uint256);
    function isTokenOwner(uint256 tokenId, address member) external view returns (bool);

    function proposalCount() external view returns (uint256);
    function proposals(uint256) external view returns (address);
    function isProposal(address proposal) external view returns (bool);

    function setDAOName(string memory newDAOName) external;
    function setDAOMetadata(string memory newDAOMetadata) external;
    function setQuorumThreshold(uint256 newQuorumThreshold) external;
    function setSupportThreshold(uint256 newSupportThreshold) external;
    function setMinVotePeriod(uint256 newMinVotePeriod) external;
}