// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Reserve Economy Crypto Coin (RECC)

    - Fixed supply: 500,000,000 RECC
    - Vesting: 199M released over 20 years to Account B
    - Decimals: 18
    - No inflation
    - No admin privileges
    - Store-of-value + emission schedule

    Network: RECC / EVM Compatible
    Author: RECCNETWORK Blockchain Ecosystem
*/

contract RECC {

    /* =============================================================
                                METADATA
    ============================================================= */

    string public constant name = "Reserve Economy Crypto Coin";
    string public constant symbol = "RECC";
    uint8  public constant decimals = 18;

    uint256 public constant TOTAL_SUPPLY =
        500_000_000 * 10 ** uint256(decimals);

    /* =============================================================
                            ADDRESSES
    ============================================================= */

    address public constant ACCOUNT_A =
        0x84196c3fdB7Cab79cFEf56465c593322fa3B03e3;

    address public constant ACCOUNT_B =
        0x255E75e45800C59dba2543841Af57898165D9Cb5;

    /* =============================================================
                            TOKEN STORAGE
    ============================================================= */

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /* =============================================================
                            EVENTS
    ============================================================= */

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event VestingClaim(uint256 amount);

    /* =============================================================
                            VESTING
    ============================================================= */

    uint256 public constant VESTING_TOTAL =
        199_000_000 * 10 ** uint256(decimals);

    uint256 public constant VESTING_DURATION =
        20 * 365 days; // 20 years

    uint256 public immutable vestingStart;

    uint256 public vestingClaimed;

    /* =============================================================
                                PERMIT
    ============================================================= */

    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

    mapping(address => uint256) public nonces;

    /* =============================================================
                              CONSTRUCTOR
    ============================================================= */

    constructor() {

        vestingStart = block.timestamp;

        uint256 supplyA =
            300_000_000 * 10 ** uint256(decimals);

        uint256 supplyB =
            1_000_000 * 10 ** uint256(decimals);

        uint256 vestingPool =
            VESTING_TOTAL;

        require(
            supplyA + supplyB + vestingPool == TOTAL_SUPPLY,
            "supply mismatch"
        );

        balanceOf[ACCOUNT_A] = supplyA;
        balanceOf[ACCOUNT_B] = supplyB;
        balanceOf[address(this)] = vestingPool;

        emit Transfer(address(0), ACCOUNT_A, supplyA);
        emit Transfer(address(0), ACCOUNT_B, supplyB);
        emit Transfer(address(0), address(this), vestingPool);

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

    /* =============================================================
                            VESTING LOGIC
    ============================================================= */

    function vestedAmount() public view returns (uint256) {

        uint256 elapsed = block.timestamp - vestingStart;

        if (elapsed >= VESTING_DURATION) {
            return VESTING_TOTAL;
        }

        return (VESTING_TOTAL * elapsed) / VESTING_DURATION;
    }

    function claimVested() external {

        require(msg.sender == ACCOUNT_B, "not authorized");

        uint256 totalVested = vestedAmount();

        uint256 claimable = totalVested - vestingClaimed;

        require(claimable > 0, "nothing to claim");

        vestingClaimed += claimable;

        _transfer(address(this), ACCOUNT_B, claimable);

        emit VestingClaim(claimable);
    }

    /* =============================================================
                          ERC20 CORE
    ============================================================= */

    function transfer(address to, uint256 value)
        external
        returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        external
        returns (bool)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function increaseAllowance(address spender, uint256 added)
        external
        returns (bool)
    {
        allowance[msg.sender][spender] += added;

        emit Approval(
            msg.sender,
            spender,
            allowance[msg.sender][spender]
        );

        return true;
    }

    function decreaseAllowance(address spender, uint256 subtracted)
        external
        returns (bool)
    {
        uint256 current = allowance[msg.sender][spender];

        require(current >= subtracted, "low allowance");

        allowance[msg.sender][spender] = current - subtracted;

        emit Approval(
            msg.sender,
            spender,
            allowance[msg.sender][spender]
        );

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {

        uint256 allowed = allowance[from][msg.sender];

        require(allowed >= value, "allowance exceeded");

        allowance[from][msg.sender] = allowed - value;

        _transfer(from, to, value);

        return true;
    }

    /* =============================================================
                            INTERNAL
    ============================================================= */

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {

        require(to != address(0), "zero address");
        require(balanceOf[from] >= value, "balance low");

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);
    }

    /* =============================================================
                                PERMIT
    ============================================================= */

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {

        require(deadline >= block.timestamp, "expired");

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

        address recovered = ecrecover(digest, v, r, s);

        require(recovered == owner, "invalid signature");

        allowance[owner][spender] = value;

        emit Approval(owner, spender, value);
    }

    /* =============================================================
                        RESCUE (SAFETY)
    ============================================================= */

    function rescueTokens(address token, uint256 amount)
        external
    {
        require(token != address(this), "cannot rescue RECC");

        (bool success,) =
            token.call(
                abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    msg.sender,
                    amount
                )
            );

        require(success, "rescue failed");
    }
}

