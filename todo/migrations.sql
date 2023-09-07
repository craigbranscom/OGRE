CREATE TABLE IF NOT EXISTS blockchains (
    chain_id        int primary key,
    chain_name      varchar(64),
    api_endpoint    varchar(64),
    last_block      int
);

CREATE TABLE IF NOT EXISTS contracts (
    contract_address    varchar(64) primary key,
    contract_type       varchar(64),
    created_timestamp   date,
    block_number        int
);

CREATE TABLE IF NOT EXISTS factories (
    factory_address     varchar(64) primary key,
    created_timestamp   date,
    block_number        int
);

CREATE TABLE IF NOT EXISTS daos (
    dao_address         varchar(64) primary key,
    nft_address         varchar(64),
    member_count        int,
    created_timestamp   date,
    block_number        int
);

CREATE TABLE IF NOT EXISTS proposals (
    proposal_id         int primary key,
    proposal_address    varchar(64),
    dao_address         varchar(64),
    vote_count          int,
    no_count            int,
    yes_count           int,
    abstain_count       int,
    passed              boolean
);

CREATE TABLE IF NOT EXISTS members (
    member_id       int primary key,
    dao_address     varchar(64),
    nft_address     varchar(64),
    token_id        int
);

CREATE TABLE IF NOT EXISTS votes (
    vote_id             int primary key,
    proposal_address    varchar(64),
    token_id            int,
    vote                int
);
