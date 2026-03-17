RECC Developer Tools

Developer tools for deploying smart contracts on RECCNETWORK.

This repository provides a ready-to-use Hardhat environment configured to deploy contracts on the RECC blockchain.

---

About RECCNETWORK

RECCNETWORK is an EVM-compatible blockchain designed for digital economy, Web3 games, payments, and decentralized applications.

Developers can deploy Solidity smart contracts exactly as they would on Ethereum or other EVM networks.

---

Requirements

Before using this repository you need:

- Node.js (v18 or newer recommended)
- npm
- MetaMask or any EVM wallet
- Some RTS tokens for gas

---

Install Dependencies

Clone the repository:

git clone
https://github.com/RECC-01/recc-dev-tools.git
cd recc-dev-tools

Install dependencies:

npm install

---

Configure Environment

Create a ".env" file from the example:

cp .env.example .env

Edit ".env" and add your wallet private key.

Example:

PRIVATE_KEY=your_wallet_private_key
RECC_RPC=https://rpc.reccnetwork.com

---

Hardhat Configuration

The network configuration is already included in "hardhat.config.js".

Example network setup:

recc:
  chainId: 24885
  rpc: https://rpc.reccnetwork.com

---

Example Deploy Script

An example deploy script is included:

scripts/deploy_luna.js

This script demonstrates how to deploy a smart contract on RECCNETWORK.

---

Deploy a Contract

Run the following command:

npx hardhat run scripts/deploy_luna.js --network recc

After deployment the contract address will be printed in the terminal.

---

Contracts Included

Example contracts included in this repository:

contracts/
 ├ LUNA.sol
 ├ RECC.sol
 ├ WRTS.sol
 ├ WUSDT.sol

These are provided as examples for development and testing.

---

EVM Compatibility

RECCNETWORK supports:

- Solidity
- Hardhat
- Web3.js
- Ethers.js
- MetaMask
- ERC-20 tokens
- ERC-721 NFTs
- ERC-1155 tokens

Any Ethereum smart contract can be deployed without modification.

---

Network Information

Network Name: RECCNETWORK
Chain ID: 24885
Currency Symbol: RTS

RPC Endpoint:

https://rpc.reccnetwork.com

---

License

MIT License

---

RECC Group Holdings

RECCNETWORK is developed and maintained by RECC Group Holdings.

Official repositories:

https://github.com/RECC-01
