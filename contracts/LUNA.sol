// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    LUNA Token

    Network: RECCNETWORK / EVM Compatible
    Author: RECCNETWORK Blockchain Ecosystem

    Supply:
    - Max: 10B
    - Premine: 5B
    - Emission: 1B per year (5 years)
*/

contract LUNA {

    string public constant name = "LUNA";
    string public constant symbol = "LUNA";
    uint8  public constant decimals = 18;

    uint256 public constant MAX_SUPPLY =
        10_000_000_000 * 1e18;

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    address public emissionWallet;

    uint256 public constant EMISSION_PER_YEAR =
        1_000_000_000 * 1e18;

    uint256 public emissionStart;
    uint256 public emissionClaimed;

    uint256 public constant YEARS = 5;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ClaimEmission(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    constructor(
        address premineWallet,
        address _emissionWallet
    ) {
        require(premineWallet != address(0), "zero");
        require(_emissionWallet != address(0), "zero");

        owner = msg.sender;
        emissionWallet = _emissionWallet;
        emissionStart = block.timestamp;

        uint256 premine =
            5_000_000_000 * 1e18;

        _mint(premineWallet, premine);
    }

    function transfer(address to, uint256 value)
        external returns (bool)
    {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value)
        external returns (bool)
    {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {

        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "allowance");

        allowance[from][msg.sender] = allowed - value;

        _transfer(from, to, value);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {

        require(balanceOf[from] >= value, "balance");

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 amount)
        internal
    {
        require(totalSupply + amount <= MAX_SUPPLY, "max");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function claimEmission()
        external
        onlyOwner
    {
        require(
            block.timestamp >= emissionStart + 365 days,
            "year not passed"
        );

        require(
            emissionClaimed < YEARS,
            "finished"
        );

        emissionClaimed++;

        _mint(
            emissionWallet,
            EMISSION_PER_YEAR
        );

        emissionStart = block.timestamp;

        emit ClaimEmission(EMISSION_PER_YEAR);
    }

    function transferOwnership(address newOwner)
        external
        onlyOwner
    {
        owner = newOwner;
    }
}
