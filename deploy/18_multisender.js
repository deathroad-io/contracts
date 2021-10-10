const {
    chainNameById,
    chainIdByName,
    saveDeploymentData,
    getContractAbi,
    log
  } = require("../js-helpers/deploy");
  
  const _ = require('lodash');
  const addresses = require('../js-helpers/data/addresses.json')
  module.exports = async (hre) => {
    const { ethers, getNamedAccounts } = hre;
    const { deployer } = await getNamedAccounts();
    const network = await hre.network;
    const deployData = {};

    const signers = await ethers.getSigners()
    const chainId = chainIdByName(network.name);

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~');
    log('DeathRoad MultiSender deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');

    if (parseInt(chainId) == 31337) return

    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address

    log('  Deploying MultiSender Token...');
    const DRACE = await ethers.getContractFactory('DRACE');
    const drace = await DRACE.attach(draceAddress)
    log('  - DRACE:         ', drace.address);

    const MultiSender = await ethers.getContractFactory('MultiSender');
    const MultiSenderInstance = await MultiSender.deploy()
    const multiSender = await MultiSenderInstance.deployed()
    log('  - MultiSender:         ', multiSender.address);

    deployData['MultiSender'] = {
      abi: getContractAbi('MultiSender'),
      address: multiSender.address,
      deployTransaction: multiSender.deployTransaction,
    }

    //approving
    await drace.approve(multiSender.address, ethers.utils.parseEther('1000000000'))

    await multiSender.sendToMany(draceAddress, addresses, ethers.utils.parseEther('1000000'), {gasLimit: 10000000})

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['multisender']
  