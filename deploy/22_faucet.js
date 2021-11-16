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
    log('DeathRoad Faucet Contract deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');

    if (parseInt(chainId) == 31337) return

    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
    log('  Deploying Farming Contract...');
    const Faucet = await ethers.getContractFactory('Faucet');
    const FaucetInstance = await Faucet.deploy()
    const faucet = await FaucetInstance.deployed()
    log('  - Faucet:         ', faucet.address);
    deployData['Faucet'] = {
      abi: getContractAbi('Faucet'),
      address: faucet.address,
      deployTransaction: faucet.deployTransaction,
    }

    await faucet.initialize(draceAddress)

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['faucet']
  