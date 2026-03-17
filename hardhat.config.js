require("dotenv").config();

module.exports = {
  solidity: "0.8.24",

  networks: {
    reccnetwork: {
      url: process.env.RECC_RPC,
      chainId: 24885,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
