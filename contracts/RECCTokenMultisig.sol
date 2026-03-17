// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*

████████████████████████████████████████████████████████████████
                        RECCNETWORK
              Sovereign Blockchain Infrastructure
████████████████████████████████████████████████████████████████

Network
RECCNETWORK

Protocol
RECCNETWORK Blockchain Ecosystem

Organization
RECC Group Holdings

Contract
RECC Token Multisig Controller

Standard
IRECC-09 Institutional Multisig Standard

Module
Token Infrastructure

Security Level
Institutional Grade

Features
- M-of-N multisig
- max 7 signers
- contract-only execution
- Contract Registry
- Token Registry
- Permission Layer
- institutional token control

Author
RECCNETWORK Blockchain Ecosystem

© RECC Group Holdings

*/

contract RECCTokenMultisig {

    /* ------------------------------------------------ */
    /* CONSTANTS                                        */
    /* ------------------------------------------------ */

    uint256 public constant MAX_OWNERS = 7;

    /* ------------------------------------------------ */
    /* OWNERS                                           */
    /* ------------------------------------------------ */

    address[] public owners;

    mapping(address => bool) public isOwner;

    uint256 public required;

    /* ------------------------------------------------ */
    /* REENTRANCY                                       */
    /* ------------------------------------------------ */

    uint256 private unlocked = 1;

    modifier nonReentrant() {
        require(unlocked == 1,"REENTRANCY");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender],"NOT_OWNER");
        _;
    }

    /* ------------------------------------------------ */
    /* CONTRACT REGISTRY                                */
    /* ------------------------------------------------ */

    mapping(address => bool) public registeredContracts;

    event ContractRegistered(address contractAddress);

    event ContractRemoved(address contractAddress);

    function registerContract(address contractAddress)
        external
        onlyOwner
    {
        require(contractAddress != address(0),"ZERO_ADDR");

        registeredContracts[contractAddress] = true;

        emit ContractRegistered(contractAddress);
    }

    function removeContract(address contractAddress)
        external
        onlyOwner
    {
        registeredContracts[contractAddress] = false;

        emit ContractRemoved(contractAddress);
    }

    /* ------------------------------------------------ */
    /* TOKEN REGISTRY                                   */
    /* ------------------------------------------------ */

    mapping(address => bool) public registeredTokens;

    event TokenRegistered(address token);

    event TokenRemoved(address token);

    function registerToken(address token)
        external
        onlyOwner
    {
        require(token != address(0),"ZERO_ADDR");

        registeredTokens[token] = true;

        emit TokenRegistered(token);
    }

    function removeToken(address token)
        external
        onlyOwner
    {
        registeredTokens[token] = false;

        emit TokenRemoved(token);
    }

    /* ------------------------------------------------ */
    /* PERMISSION LAYER                                 */
    /* ------------------------------------------------ */

    mapping(address => bool) public permittedTargets;

    event PermissionGranted(address target);

    event PermissionRevoked(address target);

    function grantPermission(address target)
        external
        onlyOwner
    {
        permittedTargets[target] = true;

        emit PermissionGranted(target);
    }

    function revokePermission(address target)
        external
        onlyOwner
    {
        permittedTargets[target] = false;

        emit PermissionRevoked(target);
    }

    /* ------------------------------------------------ */
    /* TRANSACTION STRUCT                               */
    /* ------------------------------------------------ */

    struct Transaction {

        address target;

        uint256 value;

        bytes data;

        bool executed;

        uint256 confirmations;
    }

    /* ------------------------------------------------ */
    /* STORAGE                                          */
    /* ------------------------------------------------ */

    uint256 public txCount;

    mapping(uint256 => Transaction) public transactions;

    mapping(uint256 => mapping(address => bool)) public approved;

    /* ------------------------------------------------ */
    /* EVENTS                                           */
    /* ------------------------------------------------ */

    event SubmitTx(uint256 indexed txId,address indexed target);

    event ConfirmTx(address indexed owner,uint256 indexed txId);

    event ExecuteTx(uint256 indexed txId);

    event OwnerAdded(address owner);

    event OwnerRemoved(address owner);

    event RequirementChanged(uint256 required);

    /* ------------------------------------------------ */
    /* CONSTRUCTOR                                      */
    /* ------------------------------------------------ */

    constructor(
        address[] memory _owners,
        uint256 _required
    ) {

        require(_owners.length > 0,"NO_OWNERS");

        require(_owners.length <= MAX_OWNERS,"MAX_OWNERS");

        require(
            _required > 0 && _required <= _owners.length,
            "BAD_REQUIREMENT"
        );

        for(uint256 i=0;i<_owners.length;i++){

            address owner = _owners[i];

            require(owner != address(0),"ZERO_ADDR");

            require(!isOwner[owner],"DUPLICATE");

            isOwner[owner] = true;

            owners.push(owner);
        }

        required = _required;
    }

    /* ------------------------------------------------ */
    /* SUBMIT TRANSACTION                               */
    /* ------------------------------------------------ */

    function submitTransaction(
        address target,
        uint256 value,
        bytes calldata data
    )
        external
        onlyOwner
        returns(uint256 txId)
    {

        require(target != address(0),"ZERO_TARGET");

        require(target.code.length > 0,"TARGET_NOT_CONTRACT");

        require(permittedTargets[target],"TARGET_NOT_ALLOWED");

        txId = txCount;

        transactions[txId] = Transaction({
            target: target,
            value: value,
            data: data,
            executed: false,
            confirmations: 0
        });

        txCount++;

        emit SubmitTx(txId,target);
    }

    /* ------------------------------------------------ */
    /* CONFIRM TRANSACTION                              */
    /* ------------------------------------------------ */

    function confirmTransaction(uint256 txId)
        external
        onlyOwner
    {

        require(txId < txCount,"TX_NOT_EXIST");

        require(!approved[txId][msg.sender],"ALREADY_CONFIRMED");

        approved[txId][msg.sender] = true;

        transactions[txId].confirmations++;

        emit ConfirmTx(msg.sender,txId);
    }

    /* ------------------------------------------------ */
    /* EXECUTE TRANSACTION                              */
    /* ------------------------------------------------ */

    function executeTransaction(uint256 txId)
        external
        nonReentrant
    {

        require(txId < txCount,"TX_NOT_EXIST");

        Transaction storage txn = transactions[txId];

        require(!txn.executed,"TX_EXECUTED");

        require(
            txn.confirmations >= required,
            "NOT_ENOUGH_CONFIRMATIONS"
        );

        txn.executed = true;

        (bool success,) =
            txn.target.call{value: txn.value}(txn.data);

        require(success,"TX_FAILED");

        emit ExecuteTx(txId);
    }

    /* ------------------------------------------------ */
    /* OWNER MANAGEMENT                                 */
    /* ------------------------------------------------ */

    function addOwner(address newOwner)
        external
        onlyOwner
    {

        require(newOwner != address(0),"ZERO_ADDR");

        require(!isOwner[newOwner],"EXISTS");

        require(owners.length < MAX_OWNERS,"MAX");

        isOwner[newOwner] = true;

        owners.push(newOwner);

        emit OwnerAdded(newOwner);
    }

    function removeOwner(address owner)
        external
        onlyOwner
    {

        require(isOwner[owner],"NOT_OWNER");

        isOwner[owner] = false;

        for(uint256 i=0;i<owners.length;i++){

            if(owners[i] == owner){

                owners[i] = owners[owners.length-1];

                owners.pop();

                break;
            }
        }

        if(required > owners.length){

            changeRequirement(owners.length);
        }

        emit OwnerRemoved(owner);
    }

    function changeRequirement(uint256 _required)
        public
        onlyOwner
    {

        require(_required > 0,"ZERO");

        require(_required <= owners.length,"TOO_HIGH");

        required = _required;

        emit RequirementChanged(_required);
    }

    /* ------------------------------------------------ */
    /* VIEW FUNCTIONS                                   */
    /* ------------------------------------------------ */

    function getOwners()
        external
        view
        returns(address[] memory)
    {
        return owners;
    }

    /* ------------------------------------------------ */
    /* RECEIVE                                          */
    /* ------------------------------------------------ */

    receive() external payable {}

}
