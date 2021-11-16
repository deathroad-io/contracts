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
    log('DeathRoad xDrace Migrator Contract deployment');
    log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');

    log('  Using Network: ', chainNameById(chainId));
    log('  Using Accounts:');
    log('  - Deployer:          ', signers[0].address);
    log('  - network id:          ', chainId);
    log(' ');

    if (parseInt(chainId) == 31337) return

    const xdraceAddress = require(`../deployments/${chainId}/xDRACE.json`).address
    const xdrace2Address = require(`../deployments/${chainId}/xDRACE2.json`).address
    log('  Deploying xDraceMigrator Contract...');
    const xDraceMigrator = await ethers.getContractFactory('xDraceMigrator');
    const xDraceMigratorInstance = await xDraceMigrator.deploy()
    const migrator = await xDraceMigratorInstance.deployed()
    log('  - xDraceMigrator:         ', migrator.address);

    await migrator.initialize(xdraceAddress, xdrace2Address)
    deployData['xDraceMigrator'] = {
      abi: getContractAbi('xDraceMigrator'),
      address: migrator.address,
      deployTransaction: migrator.deployTransaction,
    }

    //set minter
    const xDRACE2 = await ethers.getContractFactory('xDRACE2');
    const xdrace2 = await xDRACE2.attach(xdrace2Address)
    await xdrace2.setMinters([migrator.address], true)

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['xdracemigrator']
  