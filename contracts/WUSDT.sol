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
WUSDT — Wrapped USDT Bridge Token

Standard
IRECC-01 Token Standard
IRECC-02 dApp Compatibility
IRECC-03 Signature Security

Module
Cross-Chain Bridge Asset

Security Level
Institutional Grade

Description
Bridge representation of USDT on RECCNETWORK.

Minted only by the official bridge infrastructure
after verification of deposits on external chains.

Author
RECCNETWORK Blockchain Ecosystem

Copyright
© RECC Group Holdings

*/

contract WUSDT {

    /* ------------------------------------------------ */
    /* METADATA                                         */
    /* ------------------------------------------------ */

    string public constant name = "Tether USD (Bridge RECC)";
    string public constant symbol = "WUSDT";
    uint8 public constant decimals = 18;

    string public constant NETWORK = "RECCNETWORK";

    string public constant STANDARD_1 = "IRECC-01";
    string public constant STANDARD_2 = "IRECC-02";
    string public constant STANDARD_3 = "IRECC-03";

    uint256 public totalSupply;

    /* ------------------------------------------------ */
    /* SECURITY                                         */
    /* ------------------------------------------------ */

    bool public paused;
    bool public bridgeEnabled = true;

    uint256 private unlocked = 1;

    modifier nonReentrant() {
        require(unlocked == 1,"REENTRANCY");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    modifier whenNotPaused() {
        require(!paused,"PAUSED");
        _;
    }

    modifier bridgeActive() {
        require(bridgeEnabled,"BRIDGE_DISABLED");
        _;
    }

    /* ------------------------------------------------ */
    /* ROLES                                            */
    /* ------------------------------------------------ */

    address public owner;
    address public pendingOwner;
    address public bridge;

    modifier onlyOwner() {
        require(msg.sender == owner,"NOT_OWNER");
        _;
    }

    modifier onlyBridge() {
        require(msg.sender == bridge,"NOT_BRIDGE");
        _;
    }

    /* ------------------------------------------------ */
    /* TOKEN STORAGE (IRECC-01)                         */
    /* ------------------------------------------------ */

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /* ------------------------------------------------ */
    /* BRIDGE SECURITY                                  */
    /* ------------------------------------------------ */

    mapping(bytes32 => bool) public processed;

    uint256 public dailyLimit;
    uint256 public mintedToday;
    uint256 public lastDay;

    uint256 public maxMintPerTx;

    /* ------------------------------------------------ */
    /* SIGNATURE SECURITY (IRECC-03)                    */
    /* ------------------------------------------------ */

    mapping(address => uint256) public nonces;

    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /* ------------------------------------------------ */
    /* EVENTS                                           */
    /* ------------------------------------------------ */

    event Transfer(address indexed from,address indexed to,uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);

    event BridgeMint(address indexed to,uint256 amount,bytes32 indexed txHash);
    event BridgeBurn(address indexed from,uint256 amount,string target);

    event BridgeChanged(address indexed newBridge);
    event BridgeStatus(bool enabled);

    event OwnershipTransferStarted(address indexed oldOwner,address indexed newOwner);
    event OwnershipTransferred(address indexed oldOwner,address indexed newOwner);

    event Paused(bool status);

    event DailyLimitChanged(uint256 newLimit);
    event MaxMintPerTxChanged(uint256 newLimit);

    /* ------------------------------------------------ */
    /* CONSTRUCTOR                                      */
    /* ------------------------------------------------ */

    constructor(
        address _multisigOwner,
        address _bridge,
        uint256 _dailyLimit
    ){

        require(_multisigOwner != address(0),"OWNER_ZERO");
        require(_bridge != address(0),"BRIDGE_ZERO");

        owner = _multisigOwner;
        bridge = _bridge;

        dailyLimit = _dailyLimit;
        maxMintPerTx = _dailyLimit;

        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        DOMAIN_SEPARATOR =
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name)),
                    keccak256(bytes("1")),
                    chainId,
                    address(this)
                )
            );
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
    /* OWNER CONFIGURATION                              */
    /* ------------------------------------------------ */

    function setBridge(address _bridge)
        external
        onlyOwner
    {
        require(_bridge != address(0),"ZERO");

        bridge = _bridge;

        emit BridgeChanged(_bridge);
    }

    function setPaused(bool status)
        external
        onlyOwner
    {
        paused = status;

        emit Paused(status);
    }

    function setBridgeEnabled(bool status)
        external
        onlyOwner
    {
        bridgeEnabled = status;

        emit BridgeStatus(status);
    }

    function setDailyLimit(uint256 limit)
        external
        onlyOwner
    {
        dailyLimit = limit;

        emit DailyLimitChanged(limit);
    }

    function setMaxMintPerTx(uint256 limit)
        external
        onlyOwner
    {
        maxMintPerTx = limit;

        emit MaxMintPerTxChanged(limit);
    }

    /* ------------------------------------------------ */
    /* DAILY LIMIT LOGIC                                */
    /* ------------------------------------------------ */

    function _updateDaily(uint256 amount)
        internal
    {
        uint256 day = block.timestamp / 1 days;

        if(day > lastDay){
            lastDay = day;
            mintedToday = 0;
        }

        require(amount <= dailyLimit,"LIMIT_EXCEEDED");

        mintedToday += amount;

        require(mintedToday <= dailyLimit,"DAILY_LIMIT");
    }

    /* ------------------------------------------------ */
    /* BRIDGE MINT                                      */
    /* ------------------------------------------------ */

    function bridgeMint(
        address to,
        uint256 amount,
        bytes32 txHash
    )
        external
        onlyBridge
        nonReentrant
        whenNotPaused
        bridgeActive
    {

        require(to != address(0),"ZERO_ADDR");
        require(amount > 0,"ZERO_AMOUNT");
        require(amount <= maxMintPerTx,"TX_LIMIT");

        require(!processed[txHash],"PROCESSED");

        processed[txHash] = true;

        _updateDaily(amount);

        _mint(to,amount);

        emit BridgeMint(to,amount,txHash);
    }

    /* ------------------------------------------------ */
    /* BRIDGE BURN                                      */
    /* ------------------------------------------------ */

    function bridgeBurn(
        uint256 amount,
        string calldata targetAddress
    )
        external
        nonReentrant
        whenNotPaused
    {

        require(bytes(targetAddress).length > 0,"INVALID_TARGET");

        _burn(msg.sender,amount);

        emit BridgeBurn(msg.sender,amount,targetAddress);
    }

    /* ------------------------------------------------ */
    /* INTERNAL MINT/BURN                               */
    /* ------------------------------------------------ */

    function _mint(address to,uint256 amount)
        internal
    {
        totalSupply += amount;

        balanceOf[to] += amount;

        emit Transfer(address(0),to,amount);
    }

    function _burn(address from,uint256 amount)
        internal
    {
        require(balanceOf[from] >= amount,"BALANCE");

        balanceOf[from] -= amount;

        totalSupply -= amount;

        emit Transfer(from,address(0),amount);
    }

    /* ------------------------------------------------ */
    /* TOKEN LOGIC                                      */
    /* ------------------------------------------------ */

    function approve(address spender,uint256 value)
        external
        returns(bool)
    {
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender,spender,value);

        return true;
    }

    function transfer(address to,uint256 value)
        external
        returns(bool)
    {
        _transfer(msg.sender,to,value);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    )
        external
        returns(bool)
    {

        uint256 allowed = allowance[from][msg.sender];

        if(allowed != type(uint256).max){
            allowance[from][msg.sender] = allowed - value;
        }

        _transfer(from,to,value);

        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    )
        internal
    {

        require(to != address(0),"ZERO_ADDR");
        require(balanceOf[from] >= value,"BALANCE");

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from,to,value);
    }

    /* ------------------------------------------------ */
    /* PERMIT (IRECC-03)                                */
    /* ------------------------------------------------ */

    function permit(
        address owner_,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {

        require(deadline >= block.timestamp,"EXPIRED");

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner_,
                            spender,
                            value,
                            nonces[owner_]++,
                            deadline
                        )
                    )
                )
            );

        address recovered = ecrecover(digest,v,r,s);

        require(
            recovered != address(0) &&
            recovered == owner_,
            "INVALID_SIG"
        );

        allowance[owner_][spender] = value;

        emit Approval(owner_,spender,value);
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
