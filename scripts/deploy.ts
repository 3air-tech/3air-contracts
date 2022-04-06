import { ethers } from "hardhat";

async function main() {
  const Air = await ethers.getContractFactory("Air");
  const airToken = await Air.deploy();

  await airToken.deployed();

  const Vesting = await ethers.getContractFactory("Vesting");
  const vesting = await Vesting.deploy(airToken.address);

  await vesting.deployed();

  console.log("3AIR deployed to:", airToken.address);
  console.log("Vesting deployed to:", vesting.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});