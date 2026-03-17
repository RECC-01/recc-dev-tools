// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*

████████████████████████████████████████████████████████████
                        RECCNETWORK
            Sovereign Blockchain Infrastructure
████████████████████████████████████████████████████████████

Token
Wrapped RTS

Native Coin
RTS — Regulatory Technical Standards

Purpose
Native wrapper token for RTS

Standards
IRECC-01 Token Standard
IRECC-02 dApp Compatibility
IRECC-03 Signature Security

Architecture
RTS (native coin)
        ↓
WRTS (wrapped token)

Features
• native coin wrapper
• deposit / withdraw RTS
• ERC20 compatible
• permit signatures
• deposit for other user
• withdraw to other address
• reentrancy protection
• fully permissionless

Network
RECCNETWORK Blockchain Ecosystem

*/

contract WRTS {

    /* =====================================================
                        METADATA
    ===================================================== */

    string public constant name = "Regulatory Technical Standards";
    string public constant symbol = "WRTS";
    string public constant DISPLAY_SYMBOL = "RTS";

    uint8 public constant decimals = 18;

    string public constant NETWORK = "RECCNETWORK";

    string public constant STANDARD_1 = "IRECC-01";
    string public constant STANDARD_2 = "IRECC-02";
    string public constant STANDARD_3 = "IRECC-03";

    uint256 public totalSupply;

    /* =====================================================
                    REENTRANCY PROTECTION
    ===================================================== */

    uint256 private unlocked = 1;

    modifier lock() {
        require(unlocked == 1,"LOCKED");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    /* =====================================================
                        IRECC-01 TOKEN STORAGE
    ===================================================== */

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /* =====================================================
                        PERMIT STORAGE
    ===================================================== */

    mapping(address => uint256) public nonces;

    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    /* =====================================================
                            EVENTS
    ===================================================== */

    event Approval(address indexed owner,address indexed spender,uint256 value);

    event Transfer(address indexed from,address indexed to,uint256 value);

    event Deposit(address indexed user,uint256 amount);

    event Withdrawal(address indexed user,uint256 amount);

    /* =====================================================
                        CONSTRUCTOR
    ===================================================== */

    constructor() {

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

    /* =====================================================
                        RECEIVE RTS
    ===================================================== */

    receive() external payable {
        deposit();
    }

    /* =====================================================
                        DEPOSIT
    ===================================================== */

    function deposit() public payable {
        _mint(msg.sender,msg.value);
    }

    function depositTo(address to) external payable {
        _mint(to,msg.value);
    }

    function depositFor(address user) external payable {
        _mint(user,msg.value);
    }

    function _mint(address to,uint256 amount) internal {

        require(amount > 0,"ZERO");

        balanceOf[to] += amount;

        totalSupply += amount;

        emit Deposit(to,amount);

        emit Transfer(address(0),to,amount);
    }

    /* =====================================================
                        WITHDRAW
    ===================================================== */

    function withdraw(uint256 amount) external lock {

        require(balanceOf[msg.sender] >= amount,"INSUFFICIENT");

        balanceOf[msg.sender] -= amount;

        totalSupply -= amount;

        (bool ok,) =
            payable(msg.sender).call{value:amount}("");

        require(ok,"RTS_SEND_FAIL");

        emit Withdrawal(msg.sender,amount);

        emit Transfer(msg.sender,address(0),amount);
    }

    function withdrawTo(address to,uint256 amount) external lock {

        require(to != address(0),"ZERO_ADDR");

        require(balanceOf[msg.sender] >= amount,"INSUFFICIENT");

        balanceOf[msg.sender] -= amount;

        totalSupply -= amount;

        (bool ok,) =
            payable(to).call{value:amount}("");

        require(ok,"RTS_SEND_FAIL");

        emit Withdrawal(to,amount);

        emit Transfer(msg.sender,address(0),amount);
    }

    /* =====================================================
                        IRECC-01 TOKEN LOGIC
    ===================================================== */

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

    function transferFrom(address from,address to,uint256 value)
        external
        returns(bool)
    {

        uint256 allowed = allowance[from][msg.sender];

        if(allowed != type(uint256).max){

            allowance[from][msg.sender] =
                allowed - value;
        }

        _transfer(from,to,value);

        return true;
    }

    function _transfer(address from,address to,uint256 value)
        internal
    {

        require(to != address(0),"ZERO_ADDR");

        require(balanceOf[from] >= value,"BALANCE");

        balanceOf[from] -= value;

        balanceOf[to] += value;

        emit Transfer(from,to,value);
    }

    /* =====================================================
                        PERMIT (IRECC-03)
    ===================================================== */

    function permit(
        address owner,
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
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            );

        address recovered =
            ecrecover(digest,v,r,s);

        require(
            recovered != address(0) &&
            recovered == owner,
            "INVALID_SIG"
        );

        allowance[owner][spender] = value;

        emit Approval(owner,spender,value);
    }
}
