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
    log('DeathRoad Treasury deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  
    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');
  
    log('  Deploying Treasury Contract...');
    if (parseInt(chainId) == 31337) return;
  
    //reading DRACE token address
    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  
    const Foundation = await ethers.getContractFactory('Foundation');
    const FoundationInstance = await Foundation.deploy()
    const foundation = await FoundationInstance.deployed()
    log('  - Foundation:         ', foundation.address);
  
    deployData['Foundation'] = {
      abi: getContractAbi('Foundation'),
      address: foundation.address,
      deployTransaction: foundation.deployTransaction,
    }

    const PlayToEarnTreasury = await ethers.getContractFactory('PlayToEarnTreasury');
    const PlayToEarnTreasuryInstance = await PlayToEarnTreasury.deploy()
    const playToEarnTreasury = await PlayToEarnTreasuryInstance.deployed()
    log('  - PlayToEarnTreasury:         ', playToEarnTreasury.address);
  
    deployData['PlayToEarnTreasury'] = {
      abi: getContractAbi('PlayToEarnTreasury'),
      address: playToEarnTreasury.address,
      deployTransaction: playToEarnTreasury.deployTransaction,
    }

    const LiquidityAdder = await ethers.getContractFactory('LiquidityAdder');
    const LiquidityAdderInstance = await LiquidityAdder.deploy()
    const liquidityAdder = await LiquidityAdderInstance.deployed()
    log('  - LiquidityAdder:         ', liquidityAdder.address);
  
    deployData['LiquidityAdder'] = {
      abi: getContractAbi('LiquidityAdder'),
      address: liquidityAdder.address,
      deployTransaction: liquidityAdder.deployTransaction,
    }

    await liquidityAdder.initialize(draceAddress, "0xd4faed83dea32db211df9fcac83dd366236636e6")    
  
    const RevenueDistributor = await ethers.getContractFactory('RevenueDistributor');
    const RevenueDistributorInstance = await RevenueDistributor.deploy()
    const revenueDistributor = await RevenueDistributorInstance.deployed()
    log('  - RevenueDistributor:         ', revenueDistributor.address);
  
    deployData['RevenueDistributor'] = {
      abi: getContractAbi('RevenueDistributor'),
      address: revenueDistributor.address,
      deployTransaction: revenueDistributor.deployTransaction,
    }

    await revenueDistributor.initialize(draceAddress, foundation.address, playToEarnTreasury.address, liquidityAdder.address);
  
    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');
  
    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['treasury']
  