// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * @notice OGRE DAO interface definition
 */
interface IOGREDAO {
    function parentDAO() external view returns (address);
    function proposalFactoryAddress() external view returns (address);
    function nftAddress() external view returns (address);

    function quorumThreshold() external view returns (uint256);
    function supportThreshold() external view returns (uint256);
    function minVoteDuration() external view returns (uint256);

    function memberCount() external view returns (uint256);
    function getMemberStatus(uint256 tokenId) external view returns (uint256);

    function proposalCount() external view returns (uint256);
    function proposals(uint256) external view returns (address);
    function isProposal(address proposal) external view returns (bool);
    
    function setQuorumThreshold(uint256 newQuorumThreshold) external;
    function setSupportThreshold(uint256 newSupportThreshold) external;
    function setMinVoteDuration(uint256 newMinVoteDuration) external;
}