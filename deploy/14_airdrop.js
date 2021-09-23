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
  
    log('  Deploying LinearAirdrop Contract...');
    if (parseInt(chainId) == 31337) return;
  
    //reading DRACE token address
    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  
    const LinearAirdrop = await ethers.getContractFactory('LinearAirdrop');
    const airdropInstance = await LinearAirdrop.deploy()
    const airdrop = await airdropInstance.deployed()
    log('  - LinearAirdrop:         ', airdrop.address);
  
    deployData['LinearAirdrop'] = {
      abi: getContractAbi('LinearAirdrop'),
      address: airdrop.address,
      deployTransaction: airdrop.deployTransaction,
    }
  
    log('  - Initializing  LinearAirdrop        ');
    await airdrop.initialize(draceAddress, signers[0].address)
  
    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');
  
    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['airdrop']
  