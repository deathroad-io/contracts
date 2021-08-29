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
    log('DeathRoad NFT Factory deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');

    log('  Deploying NFT Factory Contract...');

    //reading DRACE token address
    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address

    const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT');
    const deathRoadNFTInstance = await DeathRoadNFT.deploy()
    const deathRoadNFT = await deathRoadNFTInstance.deployed()
    log('  - DeathRoadNFT:         ', deathRoadNFT.address);

    log('  Deploying NFT Notary Contract...');
    const NotaryNFT = await ethers.getContractFactory('NotaryNFT');
    const notaryNFTInstance = await NotaryNFT.deploy()
    const notaryNFT = await notaryNFTInstance.deployed()
    log('  - NotaryNFT:         ', notaryNFT.address);

    log('  - Initializing  DeathRoadNFT        ');
    await deathRoadNFT.initialize(draceAddress, signers[0].address, notaryNFT.address)

    deployData['DeathRoadNFT'] = {
      abi: getContractAbi('DeathRoadNFT'),
      address: deathRoadNFT.address,
      deployTransaction: deathRoadNFT.deployTransaction,
    }

    deployData['NotaryNFT'] = {
      abi: getContractAbi('NotaryNFT'),
      address: notaryNFT.address,
      deployTransaction: notaryNFT.deployTransaction,
    }

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['nft']
  