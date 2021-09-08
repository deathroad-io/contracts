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
    log('DeathRoad Farming Contract deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');

    log('  Deploying Farming Contract...');
    const MasterChef = await ethers.getContractFactory('MasterChef');
    const MasterChefInstance = await MasterChef.deploy()
    const masterChef = await MasterChefInstance.deployed()
    log('  - MasterChef:         ', masterChef.address);
    deployData['MasterChef'] = {
      abi: getContractAbi('MasterChef'),
      address: masterChef.address,
      deployTransaction: masterChef.deployTransaction,
    }

    //initializing
    log('  Initializing Farming Contract...');
    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
    const nftAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`).address
    const factoryAddress = require(`../deployments/${chainId}/NFTFactory.json`).address
    await masterChef.initialize(factoryAddress, nftAddress, draceAddress,
          "0x75785F9CE180C951c8178BABadFE904ec883D820",
          ethers.utils.parseEther('5'),
          0,
          100000)

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['farm']
  