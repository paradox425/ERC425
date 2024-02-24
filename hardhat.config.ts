import { HardhatUserConfig } from "hardhat/config"
import "@nomicfoundation/hardhat-toolbox"
import "hardhat-gas-reporter"
import "@nomicfoundation/hardhat-verify"

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      { version: "0.8.20" },
      { version: "0.8.24" },
      { version: "0.4.18" },
    ],
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 21,
    enabled: true,
  }
}

export default config
