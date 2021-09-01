const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log
} = require("../js-helpers/deploy");

const _ = require('lodash');

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

  //reading DRACE token address
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`).address

  const GameControl = await ethers.getContractFactory('GameControl');
  const gameControlInstance = await GameControl.deploy()
  const gameControl = await gameControlInstance.deployed()
  log('  - GameControl:         ', gameControl.address);

  deployData['GameControl'] = {
    abi: getContractAbi('GameControl'),
    address: gameControl.address,
    deployTransaction: gameControl.deployTransaction,
  }

  log('  Deploying Token Vesting Contract...');
  const TokenVesting = await ethers.getContractFactory('TokenVesting');
  const tokenVestingInstance = await TokenVesting.deploy()
  const tokenVesting = await tokenVestingInstance.deployed()
  log('  - TokenVesting:         ', tokenVesting.address);

  deployData['TokenVesting'] = {
    abi: getContractAbi('TokenVesting'),
    address: tokenVesting.address,
    deployTransaction: tokenVesting.deployTransaction,
  }

  log('  - Initializing  TokenVesting        ');
  await tokenVesting.initialize(draceAddress, 86400 * 2)

  log('  Deploying NFTUsePeriod Contract...');
  const NFTUsePeriod = await ethers.getContractFactory('NFTUsePeriod');
  const nftUsePeriodInstance = await NFTUsePeriod.deploy()
  const nftUsePeriod = await nftUsePeriodInstance.deployed()
  log('  - NFTUsePeriod:         ', nftUsePeriod.address);
  
  deployData['NFTUsePeriod'] = {
    abi: getContractAbi('NFTUsePeriod'),
    address: nftUsePeriod.address,
    deployTransaction: nftUsePeriod.deployTransaction,
  }

  log('  - Initializing  GameControl        ');
  await gameControl.initialize(draceAddress, DeathRoadNFTAddress, "0x0C78cbB95451F38e87436C002720F4DE95768441", tokenVesting.address, nftUsePeriod.address)

  saveDeploymentData(chainId, deployData);
  log('\n  Contract Deployment Data saved to "deployments" directory.');

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
};

module.exports.tags = ['game']
