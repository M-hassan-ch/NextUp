// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const nxt_raw = await hre.ethers.getContractFactory("NextUp");
  const nft_raw = await hre.ethers.getContractFactory("AthleteERC721");
  const admin_raw = await hre.ethers.getContractFactory("Admin");

  const nxt_contract = await nxt_raw.deploy("NextUp", "NXT");
  await nxt_contract.deployed();

  const nft_contract = await nft_raw.deploy("NFT", "NFT");
  await nft_contract.deployed();

  const admin_contract = await admin_raw.deploy("100000000000000", "100000000000000", nxt_contract.address, nft_contract.address);
  await admin_contract.deployed();

  console.log(
    `Nextup:    ${nxt_contract.address}\n
    AthleteNFT: ${nft_contract.address}\n
    Admn:       ${admin_contract.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
