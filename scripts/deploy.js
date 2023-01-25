// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const rawNxt = await hre.ethers.getContractFactory("NextUp");
  const rawAdmin = await hre.ethers.getContractFactory("Admin");
  
  const nxtContract = await rawNxt.deploy("NextUp", "NXT");
  
  await nxtContract.deployed();

  const adminContract = await rawAdmin.deploy("100000000", "1", nxtContract.address);

  await adminContract.deployed();

  console.log(
    `NextUp: ${nxtContract.address}\nAdmin: ${adminContract.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
