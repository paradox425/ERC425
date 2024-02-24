const hre = require("hardhat")
import { ethers, network } from "hardhat"

async function main() {
  const signers = await ethers.getSigners()

  const name = "MyToken"
  const symbol = "MTK"
  const decimals = 18
  const totalSupply = 40000

  const ERC425Factory = await ethers.getContractFactory("PARADOX")
  const erc425 = await ERC425Factory.deploy(
    name,
    symbol,
    decimals,
    totalSupply,
    "",
  )
  await erc425.waitForDeployment()
  const contractAddress = await erc425.getAddress()
  const ownerBalance = await erc425["balanceOf(address)"](signers[0])

  console.log({
    contractAddress,
    ownerBalance,
  })
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
