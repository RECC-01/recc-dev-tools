// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*

████████████████████████████████████████████████████████████████
                        RECCNETWORK
              Sovereign Blockchain Infrastructure
████████████████████████████████████████████████████████████████

Contract
USDTBridgeLock — Cross Chain Asset Lock

Description
Locks USDT on external chains and releases USDT when WUSDT
is burned on RECCNETWORK.

Users operate automatically through relayers.
Multisig owner is only for administration and emergency recovery.

Security
Institutional Grade

*/

interface IERC20 {

    function transferFrom(address from,address to,uint256 amount) external returns(bool);

    function transfer(address to,uint256 amount) external returns(bool);

    function balanceOf(address account) external view returns(uint256);

}

contract USDTBridgeLock {

    /* ------------------------------------------------ */
    /* METADATA                                         */
    /* ------------------------------------------------ */

    string public constant NETWORK = "RECCNETWORK";
    string public constant MODULE = "Bridge Lock Contract";

    /* ------------------------------------------------ */
    /* SECURITY                                         */
    /* ------------------------------------------------ */

    bool public paused;

    uint256 private unlocked = 1;

    modifier nonReentrant(){

        require(unlocked == 1,"REENTRANCY");

        unlocked = 2;

        _;

        unlocked = 1;

    }

    modifier whenNotPaused(){

        require(!paused,"PAUSED");

        _;

    }

    /* ------------------------------------------------ */
    /* OWNERSHIP (MULTISIG ADMIN)                       */
    /* ------------------------------------------------ */

    address public owner;

    address public pendingOwner;

    modifier onlyOwner(){

        require(msg.sender == owner,"NOT_OWNER");

        _;

    }

    /* ------------------------------------------------ */
    /* RELAYER                                          */
    /* ------------------------------------------------ */

    address public relayer;

    modifier onlyRelayer(){

        require(msg.sender == relayer,"NOT_RELAYER");

        _;

    }

    /* ------------------------------------------------ */
    /* TOKEN                                            */
    /* ------------------------------------------------ */

    IERC20 public immutable usdt;

    /* ------------------------------------------------ */
    /* STORAGE                                          */
    /* ------------------------------------------------ */

    uint256 public totalLocked;

    mapping(address => uint256) public userNonce;

    mapping(bytes32 => bool) public processedDeposits;

    mapping(bytes32 => bool) public processedWithdrawals;

    /* ------------------------------------------------ */
    /* DAILY WITHDRAW LIMIT (ANTI HACK)                 */
    /* ------------------------------------------------ */

    uint256 public dailyWithdrawLimit;

    uint256 public withdrawnToday;

    uint256 public lastWithdrawDay;

    /* ------------------------------------------------ */
    /* EVENTS                                           */
    /* ------------------------------------------------ */

    event Deposit(
        address indexed user,
        uint256 amount,
        string reccAddress,
        bytes32 indexed depositId
    );

    event Withdrawal(
        address indexed user,
        uint256 amount,
        bytes32 indexed burnId
    );

    event RelayerChanged(address newRelayer);

    event Paused(bool status);

    event DailyLimitChanged(uint256 newLimit);

    event OwnershipTransferStarted(
        address indexed oldOwner,
        address indexed newOwner
    );

    event OwnershipTransferred(
        address indexed oldOwner,
        address indexed newOwner
    );

    event EmergencyRecovery(
        address indexed to,
        uint256 amount
    );

    /* ------------------------------------------------ */
    /* CONSTRUCTOR                                      */
    /* ------------------------------------------------ */

    constructor(
        address _usdt,
        address _relayer,
        uint256 _dailyLimit
    ){

        require(_usdt != address(0),"USDT_ZERO");

        require(_relayer != address(0),"RELAYER_ZERO");

        owner = msg.sender;

        relayer = _relayer;

        usdt = IERC20(_usdt);

        dailyWithdrawLimit = _dailyLimit;

    }

    /* ------------------------------------------------ */
    /* OWNERSHIP                                        */
    /* ------------------------------------------------ */

    function transferOwnership(address newOwner)
        external
        onlyOwner
    {

        require(newOwner != address(0),"ZERO");

        pendingOwner = newOwner;

        emit OwnershipTransferStarted(owner,newOwner);

    }

    function acceptOwnership()
        external
    {

        require(msg.sender == pendingOwner,"NOT_PENDING");

        address old = owner;

        owner = pendingOwner;

        pendingOwner = address(0);

        emit OwnershipTransferred(old,owner);

    }

    /* ------------------------------------------------ */
    /* ADMIN                                            */
    /* ------------------------------------------------ */

    function setPaused(bool status)
        external
        onlyOwner
    {

        paused = status;

        emit Paused(status);

    }

    function setRelayer(address newRelayer)
        external
        onlyOwner
    {

        require(newRelayer != address(0),"ZERO");

        relayer = newRelayer;

        emit RelayerChanged(newRelayer);

    }

    function setDailyWithdrawLimit(uint256 newLimit)
        external
        onlyOwner
    {

        dailyWithdrawLimit = newLimit;

        emit DailyLimitChanged(newLimit);

    }

    /* ------------------------------------------------ */
    /* DEPOSIT (USER)                                   */
    /* ------------------------------------------------ */

    function deposit(
        uint256 amount,
        string calldata reccAddress
    )
        external
        nonReentrant
        whenNotPaused
    {

        require(amount > 0,"ZERO_AMOUNT");

        require(bytes(reccAddress).length > 0,"INVALID_RECC_ADDRESS");

        bool success =
            usdt.transferFrom(
                msg.sender,
                address(this),
                amount
            );

        require(success,"TRANSFER_FAIL");

        uint256 nonce = userNonce[msg.sender]++;

        bytes32 depositId =
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    amount,
                    nonce,
                    block.chainid
                )
            );

        require(!processedDeposits[depositId],"DUPLICATE");

        processedDeposits[depositId] = true;

        totalLocked += amount;

        emit Deposit(
            msg.sender,
            amount,
            reccAddress,
            depositId
        );

    }

    /* ------------------------------------------------ */
    /* WITHDRAW (RELAYER)                               */
    /* ------------------------------------------------ */

    function releaseTokens(
        address to,
        uint256 amount,
        bytes32 burnId
    )
        external
        onlyRelayer
        nonReentrant
        whenNotPaused
    {

        require(to != address(0),"ZERO_ADDR");

        require(amount > 0,"ZERO_AMOUNT");

        require(!processedWithdrawals[burnId],"ALREADY_PROCESSED");

        require(
            usdt.balanceOf(address(this)) >= amount,
            "INSUFFICIENT_LIQUIDITY"
        );

        uint256 day = block.timestamp / 1 days;

        if(day > lastWithdrawDay){

            lastWithdrawDay = day;

            withdrawnToday = 0;

        }

        withdrawnToday += amount;

        require(
            withdrawnToday <= dailyWithdrawLimit,
            "DAILY_LIMIT"
        );

        processedWithdrawals[burnId] = true;

        bool success = usdt.transfer(to,amount);

        require(success,"TRANSFER_FAIL");

        totalLocked -= amount;

        emit Withdrawal(to,amount,burnId);

    }

    /* ------------------------------------------------ */
    /* EMERGENCY RECOVERY (MULTISIG)                    */
    /* ------------------------------------------------ */

    function emergencyRecovery(
        address to,
        uint256 amount
    )
        external
        onlyOwner
    {

        require(to != address(0),"ZERO_ADDR");

        bool success = usdt.transfer(to,amount);

        require(success,"TRANSFER_FAIL");

        emit EmergencyRecovery(to,amount);

    }

    /* ------------------------------------------------ */
    /* RESCUE TOKENS                                    */
    /* ------------------------------------------------ */

    function rescueTokens(
        address token,
        uint256 amount,
        address to
    )
        external
        onlyOwner
    {

        require(to != address(0),"ZERO");

        (bool success,bytes memory data) =
            token.call(
                abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    to,
                    amount
                )
            );

        require(
            success &&
            (data.length == 0 || abi.decode(data,(bool))),
            "RESCUE_FAIL"
        );

    }

}
