const { ethers } = require("hardhat");

async function main() {

// Example deploy script
// Replace wallets with your own addresses

  const premineWallet = "0x0000000000000000000000000000000000000001";
  const emissionWallet = "0x0000000000000000000000000000000000000002";

  console.log("Deploying LUNA contract...");

  const LUNA = await ethers.getContractFactory("LUNA");

  const luna = await LUNA.deploy(
      premineWallet,
      emissionWallet
  );

  await luna.waitForDeployment();

  const address = await luna.getAddress();

  console.log("LUNA deployed at:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

