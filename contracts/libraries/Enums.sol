// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

library Enums {

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
     * UNREGISTERED: member has not registered, or elected to unregister after previously being registered
     * REGISTERED: member is registered
     * BANNED: member has been banned and cannot be registered again
     */
    enum MemberStatus {
        UNREGISTERED,
        INVITED,
        REGISTERED,
        BANNED
    }

    /**
     * OPEN: any nft holder can register to dao as a member
     * INVITE: only dao owner can invite new members
     */
    // enum AccessType {
    //     OPEN,
    //     INVITE
    // }

    /**
     * ASK:
     * BID:
     */
    enum OrderType {
        ASK,
        BID
    }

}