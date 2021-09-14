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
    log('DeathRoad xDRACE token deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');

    log('  Deploying xDRACE Token...');
    const xDRACE = await ethers.getContractFactory('xDRACE');
    const xdraceInstance = await xDRACE.deploy(signers[0].address)
    const xdrace = await xdraceInstance.deployed()
    log('  - xDRACE:         ', xdrace.address);
    deployData['xDRACE'] = {
      abi: getContractAbi('xDRACE'),
      address: xdrace.address,
      deployTransaction: xdrace.deployTransaction,
    }

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['xdrace']
  