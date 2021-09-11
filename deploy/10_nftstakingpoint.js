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

    log('  Deploying NFTStakingPoint Contract...');
    const NFTStakingPoint = await ethers.getContractFactory('NFTStakingPoint');
    const NFTStakingPointInstance = await NFTStakingPoint.deploy()
    const nftStakingPoint = await NFTStakingPointInstance.deployed()
    log('  - NFTStakingPoint:         ', nftStakingPoint.address);
    deployData['NFTStakingPoint'] = {
      abi: getContractAbi('NFTStakingPoint'),
      address: nftStakingPoint.address,
      deployTransaction: nftStakingPoint.deployTransaction,
    }

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['nftstakingpoint']
  