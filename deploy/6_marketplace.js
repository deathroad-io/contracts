const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log
} = require("../js-helpers/deploy");

const _ = require('lodash');
const feeReceiver = "0xd91ce559ab85e32169462BB39739E4ED8babb6FE"

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();
  const network = await hre.network;
  const deployData = {};

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name);

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
  log('DeathRoad Game deployment');
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

  log('  Using Network: ', chainNameById(chainId));
  log('  Using Accounts:');
  log('  - Deployer:          ', signers[0].address);
  log('  - network id:          ', chainId);
  log(' ');

  log('  Deploying Game Control Contract...');
  if (parseInt(chainId) == 31337) return

  //reading DRACE token address
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`).address

  const MarketPlace = await ethers.getContractFactory('MarketPlace');
  const marketPlaceInstance = await MarketPlace.deploy()
  const marketPlace = await marketPlaceInstance.deployed()
  log('  - MarketPlace:         ', marketPlace.address);

  deployData['MarketPlace'] = {
    abi: getContractAbi('MarketPlace'),
    address: marketPlace.address,
    deployTransaction: marketPlace.deployTransaction,
  }

  log('  - Initializing  MarketPlace        ');
  await marketPlace.initialize(DeathRoadNFTAddress, draceAddress, feeReceiver)

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['market']
