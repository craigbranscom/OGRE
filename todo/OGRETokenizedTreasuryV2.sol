// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/access/AccessControl.sol";
// import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
// import "./abstract/NativeReceivable.sol";
import "./interfaces/IOGRE20Factory.sol";
import "./interfaces/IOGRE721Factory.sol";
import "./interfaces/IOGRE721.sol";

/**
 * @title Open Governance Referendum Engine Tokenized Treasury V2 Contract
 */
contract OGRETokenizedTreasuryV2 is AccessControl {

    modifier onlyDepositOwner(uint256 depositTokenId) {
        require(IERC721(depositTokenContractAddress).ownerOf(depositTokenId) == msg.sender, "sender not deposit token owner");
        _;
    }

    modifier onlyAllowedContract(address contractAddress) {
        require(hasRole(ALLOWED_CONTRACT, contractAddress), "contract not allowed");
        _;
    }

    enum ContractType {
        ERC20,
        ERC721
    }

    struct TokenizedDeposit {
        ContractType contractType;
        address contractAddress;
        uint256 amountOrTokenId;
    }

    bytes32 public constant TREASURY_OWNER = keccak256("TREASURY_OWNER");
    bytes32 public constant ALLOWED_CONTRACT = keccak256("ALLOWED_CONTRACT");

    address public ogre20FactoryAddress;
    address public ogre721FactoryAddress;

    mapping(address => address) public depositTokenContracts; //externalTokenContractAddress => depositTokenContractAddress
    mapping(address => mapping(uint256 => TokenizedDeposit)) public deposits; //depositTokenAddress, depositTokenId => TokenizedDeposit
    
    constructor(address erc20FactoryAddress_, address erc721FactoryAddress_) {
        // IOGRE721Factory factory = IOGRE721Factory(erc721FactoryAddress_);

        //produce deposit token contract via factory
        // depositTokenContractAddress = factory.produceOGRE721("OGRETokenizedTreasury Deposit Tokens", "DEPOSIT", address(this));

        _setupRole(TREASURY_OWNER, msg.sender);
        // _setupRole(ALLOWED_CONTRACT, depositTokenContractAddress);
        _setRoleAdmin(ALLOWED_CONTRACT, TREASURY_OWNER);
    }

    function updateAllowlist(address contractAddress, bool allowed) public onlyRole(TREASURY_OWNER) {
        if (allowed) {
            grantRole(ALLOWED_CONTRACT, contractAddress);
        } else {
            revokeRole(ALLOWED_CONTRACT, contractAddress);
        }
    }

    function createDeposit(TokenizedDeposit memory deposit) public payable onlyAllowedContract(deposit.contractAddress) returns (uint256) {
        _lastDepositId += 1;

        //transfer tokens to treasury (requires approval)
        if (deposit.contractType == ContractType.ERC20) {
            uint256 preBalance = IERC20(deposit.contractAddress).balanceOf(address(this));
            IERC20(deposit.contractAddress).transferFrom(address(this), msg.sender, deposit.amountOrTokenId);
            uint256 postBalance = IERC20(deposit.contractAddress).balanceOf(address(this));
            require(postBalance == preBalance + deposit.amountOrTokenId, "erc20 deposit not received");
        } else if (deposit.contractType == ContractType.ERC721) {
            require(IERC721(deposit.contractAddress).ownerOf(deposit.amountOrTokenId) == msg.sender, "sender not erc721 deposit owner");
            IERC721(deposit.contractAddress).safeTransferFrom(address(this), msg.sender, deposit.amountOrTokenId);
            require(IERC721(deposit.contractAddress).ownerOf(deposit.amountOrTokenId) == address(this), "erc721 deposit not received");
        }

        //insert new deposit
        deposits[_lastDepositId] = deposit;

        //mint deposit token
        IOGRE721(depositTokenContractAddress).mint(msg.sender, _lastDepositId);

        return _lastDepositId;
    }

    function redeemDeposit(address depositTokenContractAddress, uint256 depositTokenId) public {
        require(depositTokenContracts[]);

        //transfer deposit token to treasury (requires approval)
        IERC721(depositTokenContractAddress).safeTransferFrom(msg.sender, address(this),depositTokenId);

        //burn deposit token
        IOGRE721(depositTokenContractAddress).burn(depositTokenId);

        TokenizedDeposit memory deposit = deposits[depositTokenId];
        delete deposits[depositTokenId];

        //transfer deposit to caller
        if (deposit.contractType == ContractType.ERC20) {
            IERC20(deposit.contractAddress).transferFrom(address(this), msg.sender, deposit.amountOrTokenId);
        } else if (deposit.contractType == ContractType.ERC721) {
            IERC721(deposit.contractAddress).safeTransferFrom(address(this), msg.sender, deposit.amountOrTokenId);
        }
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        require(hasRole(ALLOWED_CONTRACT, msg.sender), "contract not allowed");
        // if (msg.sender == depositTokenContractAddress) {
        //     //burn deposit token
        //     IOGRE721(depositTokenContractAddress).burn(tokenId);

        //     TokenizedDeposit memory deposit = deposits[tokenId];
        //     delete deposits[tokenId];

        //     //send deposit to owner
        //     if (deposit.contractType == ContractType.ERC20) {
        //         IERC20(deposit.contractAddress).transferFrom(address(this), from, deposit.amountOrTokenId);
        //     } else {
        //         IERC721(deposit.contractAddress).safeTransferFrom(address(this), from, deposit.amountOrTokenId);
        //     }
        // } else {
        //     _lastDepositId += 1;

        //     //insert new deposit
        //     TokenizedDeposit memory deposit = TokenizedDeposit(
        //         ContractType.ERC721,
        //         from,
        //         tokenId
        //     );
        //     deposits[_lastDepositId] = deposit;

        //     //mint deposit token
        //     IOGRE721(depositTokenContractAddress).mint(from, _lastDepositId);
        // }
        // if (data.length > 0) {}
        return IERC721Receiver.onERC721Received.selector;
    }

    function _deployDepositTokenContract(ContractType contractType, address contractAddress, string memory name, string memory symbol) private returns (address) {
        address depositTokenContractAddress;
        if (contractType == ContractType.ERC20) {
            depositTokenContractAddress = IOGRE20Factory(ogre721FactoryAddress).produceOGRE20(name, symbol, address(this));
        } else if (contractType == ContractType.ERC721) {
            depositTokenContractAddress = IOGRE721Factory(ogre721FactoryAddress).produceOGRE721(name, symbol, address(this));
        }
        depositTokenContracts[contractAddress] = depositTokenContractAddress;
        depositTokenContracts[depositTokenContractAddress] = contractAddress;
        return depositTokenContractAddress;
    }

    receive() external payable {}

    fallback() external {}

}