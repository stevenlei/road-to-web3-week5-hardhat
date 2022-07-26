async function main() {
  const BullnBear = await hre.ethers.getContractFactory("BullnBear");
  const bullnbear = await BullnBear.deploy(9211);
  await bullnbear.deployed();

  console.log(`Deployed at ${bullnbear.address}`);

  const [owner] = await hre.ethers.getSigners();
  await bullnbear.safeMint(owner.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
