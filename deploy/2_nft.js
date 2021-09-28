const {
    chainNameById,
    chainIdByName,
    saveDeploymentData,
    getContractAbi,
    log
  } = require("../js-helpers/deploy");
  
  const _ = require('lodash');
  const feeReceiver = "0xd91ce559ab85e32169462BB39739E4ED8babb6FE"
  const constants = require('./constants')

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

    const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT');
    const deathRoadNFTInstance = await DeathRoadNFT.deploy()
    const deathRoadNFT = await deathRoadNFTInstance.deployed()
    log('  - DeathRoadNFT:         ', deathRoadNFT.address);

    log('  Deploying NFT Notary Contract...');
    const NotaryNFT = await ethers.getContractFactory('NotaryNFT');
    const notaryNFTInstance = await NotaryNFT.deploy()
    const notaryNFT = await notaryNFTInstance.deployed()
    log('  - NotaryNFT:         ', notaryNFT.address);

    log('  Deploying NFT Storage Contract...');
    const NFTStorage = await ethers.getContractFactory('NFTStorage');
    const NFTStorageInstance = await NFTStorage.deploy()
    const nftStorage = await NFTStorageInstance.deployed()
    log('  - NFTStorage:         ', nftStorage.address);

    log('  Deploying NFT Factory Contract...');
    const NFTFactory = await ethers.getContractFactory('NFTFactory');
    const nftFactoryInstance = await NFTFactory.deploy()
    const factory = await nftFactoryInstance.deployed()
    log('  - NFTFactory:         ', factory.address);

    log('  - Initializing  DeathRoadNFT        ');
    await deathRoadNFT.initialize(factory.address)

    log('  - Adding approver ');
    await factory.addApprover(constants.getApprover(chainId), true);
    await factory.setSettleFeeReceiver(constants.getSettler(chainId))

    //deploying fee distribution

    log('  - Initializing  NFTFactory        ');
    await factory.initialize(deathRoadNFT.address, draceAddress, feeReceiver, notaryNFT.address, nftStorage.address, ethers.constants.AddressZero)

    deployData['NFTStorage'] = {
      abi: getContractAbi('NFTStorage'),
      address: nftStorage.address,
      deployTransaction: nftStorage.deployTransaction,
    }

    deployData['DeathRoadNFT'] = {
      abi: getContractAbi('DeathRoadNFT'),
      address: deathRoadNFT.address,
      deployTransaction: deathRoadNFT.deployTransaction,
    }

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
  
  module.exports.tags = ['nft']
  