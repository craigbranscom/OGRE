// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//TODO: handle ties

library ProposalEvaluator {

    /**
     * @dev returns index with most votes
     * @param totals array of vote totals
     */
    function mostVotes(uint256[3] memory totals) internal pure returns (uint8 most) {
        for (uint8 i = 0; i < totals.length; i++) {
            if (totals[i] > totals[most]) {
                most = i;
            }
        }
        return most;
    }

    /**
     * @dev returns index with least votes
     * @param totals array of vote totals
     */
    function leastVotes(uint256[3] memory totals) internal pure returns (uint8 least) {
        for (uint8 i = 0; i < totals.length; i++) {
            if (totals[i] < totals[least]) {
                least = i;
            }
        }
        return least;
    }

    /**
     * @dev returns true if quorum was reached
     * @param threshold percentage threshold for reaching quorum (555 = 5.55%)
     * @param voters number of unique voters that participated on proposal
     * @param audience total number of possible voters
     */
    function hasQuorum(uint256 threshold, uint256 voters, uint256 audience) internal pure returns (bool) {
        bool quorum;
        if (threshold * audience / 10000 >= voters) {
            quorum = true;
        }
        return quorum;
    }

    /**
     * @dev returns true if support was reached
     * @param threshold percentage threshold for reaching support (555 = 5.55%)
     * @param voters number of unique voters that participated on proposal
     * @param audience total number of possible voters
     */
    function hasSupport(uint256 threshold, uint256 voters, uint256 audience) internal pure returns (bool) {
        bool support;
        if (threshold * audience / 10000 >= voters) {
            support = true;
        }
        return support;
    }

}