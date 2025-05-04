// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

library OGREDAOEnums {

    /**
     * UNREGISTERED: member has not registered, or elected to unregister after previously being registered
     * REGISTERED: member is registered
     * BANNED: member has been banned and cannot be registered again
     */
    enum MemberStatus {
        UNREGISTERED,
        REGISTERED,
        BANNED
    }

    /**
     * OPEN: any nft holder can self-register as a member
     * INVITE: only dao members can register a member
     * PRIVATE: only dao can register a member
     */
    enum AccessType {
        OPEN,
        INVITE,
        PRIVATE
    }

}

library OGREMarketEnums {
    
    /**
     * ASK:
     * BID:
     */
    enum OrderType {
        ASK,
        BID
    }

    /**
     * ERC20:
     * ERC721:
     * ERC1155:
     */
    enum ContractType {
        ERC20,
        ERC721,
        ERC1155
    }
    
}

library OGREProposalEnums {
    
    /**
     * Proposal Status Flow:
     *     PROPOSED - CANCELLED
     *        |    \
     *      PASSED  FAILED
     *        |
     *     EXECUTED
     */
    enum ProposalStatus {
        PROPOSED,
        CANCELLED,
        FAILED,
        PASSED,
        EXECUTED
    }

    /**
     * NO:
     * YES:
     * ABSTAIN:
     */
    enum VoteDirection {
        NO,
        YES,
        ABSTAIN
    }

}