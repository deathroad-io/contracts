const {
    chainNameById,
    chainIdByName,
    saveDeploymentData,
    getContractAbi,
    getTxGasCost,
    log,
    supportedChainIds,
    approvers
  } = require("../js-helpers/deploy");
  
  const _ = require('lodash');
  
  module.exports = async (hre) => {
      const { ethers, upgrades, getNamedAccounts } = hre;
      const { deployer, protocolOwner, trustedForwarder } = await getNamedAccounts();
      const network = await hre.network;
      const deployData = {};
  
      const chainId = chainIdByName(network.name);
      const alchemyTimeout = chainId === 31337 ? 0 : (chainId === 1 ? 5 : 3);
  
      log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
      log('DTO Multichain Bridge Protocol - Contract Deployment');
      log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  
      log('  Using Network: ', chainNameById(chainId));
      log('  Using Accounts:');
      log('  - Deployer:          ', deployer);
      log('  - network id:          ', chainId);
      log('  - Owner:             ', protocolOwner);
      log('  - Trusted Forwarder: ', trustedForwarder);
      log(' ');
  
      log('  Deploying GenericBridge...');
      const GenericBridge = await ethers.getContractFactory('GenericBridge');
      const GenericBridgeInstance = await GenericBridge.deploy()
      const genericBridge = await GenericBridgeInstance.deployed()
      log('  - GenericBridge:         ', genericBridge.address);
      deployData['GenericBridge'] = {
        abi: getContractAbi('GenericBridge'),
        address: genericBridge.address,
        deployTransaction: genericBridge.deployTransaction,
      }
  
      await genericBridge.setSupportedChainIds(supportedChainIds, true)
      await genericBridge.addApprovers(approvers)
  
      saveDeploymentData(chainId, deployData);
      log('\n  Contract Deployment Data saved to "deployments" directory.');
  
      log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['game']
  