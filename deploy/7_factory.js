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
    const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`).address

    const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT');
    const deathRoadNFT = await DeathRoadNFT.attach(DeathRoadNFTAddress)
    log('  - DeathRoadNFT:         ', deathRoadNFT.address);

    log('  Deploying NFT Notary Contract...');
    const NotaryNFT = await ethers.getContractFactory('NotaryNFT');
    const notaryNFTInstance = await NotaryNFT.deploy()
    const notaryNFT = await notaryNFTInstance.deployed()
    log('  - NotaryNFT:         ', notaryNFT.address);

    log('  Deploying NFT Factory Contract...');
    const NFTFactory = await ethers.getContractFactory('NFTFactory');
    const nftFactoryInstance = await NFTFactory.deploy()
    const factory = await nftFactoryInstance.deployed()
    log('  - NFTFactory:         ', factory.address);

    log('  - Initializing  DeathRoadNFT        ');
    await deathRoadNFT.setFactory(factory.address)

    log('  - Adding approver ');
    await factory.addApprover('0x75785F9CE180C951c8178BABadFE904ec883D820', true);
    await factory.setSettleFeeReceiver("0xD0e3376e1c3Af2C11730aA4E89BE839D4a1BD761")

    log('  - Initializing  NFTFactory        ');
    await factory.initialize(deathRoadNFT.address, draceAddress, signers[0].address, notaryNFT.address)

    deployData['NFTFactory'] = {
      abi: getContractAbi('NFTFactory'),
      address: factory.address,
      deployTransaction: factory.deployTransaction,
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
  
  module.exports.tags = ['factory']
  