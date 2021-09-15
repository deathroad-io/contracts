const {
    chainNameById,
    chainIdByName,
    saveDeploymentData,
    getContractAbi,
    log
  } = require("../js-helpers/deploy");
  
  const _ = require('lodash');
  const feeReceiver = "0xd91ce559ab85e32169462BB39739E4ED8babb6FE"

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

    log('  Deploying NFT FactoryV2 Contract...');

    //reading DRACE token address
    const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
    const xdraceAddress = require(`../deployments/${chainId}/xDRACE.json`).address
    const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`).address
    const NFTStorageAddress = require(`../deployments/${chainId}/NFTStorage.json`).address
    const MasterChefAddress = require(`../deployments/${chainId}/MasterChef.json`).address
    const oldFactory = require(`../deployments/${chainId}/NFTFactory.json`).address

    const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT');
    const deathRoadNFT = await DeathRoadNFT.attach(DeathRoadNFTAddress)
    log('  - DeathRoadNFT:         ', deathRoadNFT.address);

    const MasterChef = await ethers.getContractFactory('MasterChef');
    const masterchef = await MasterChef.attach(MasterChefAddress)
    log('  - DeathRoadNFT:         ', deathRoadNFT.address);

    log('  Deploying NFT Factoryv2 Contract...');
    const NFTFactoryV2 = await ethers.getContractFactory('NFTFactoryV2');
    const nftFactoryV2Instance = await NFTFactoryV2.deploy()
    const factoryV2 = await nftFactoryV2Instance.deployed()
    log('  - NFTFactoryV2:         ', factoryV2.address);

    log('  Deploying NFT Notary Contract...');
    const NotaryNFT = await ethers.getContractFactory('NotaryNFT');
    const notaryNFTInstance = await NotaryNFT.deploy()
    const notaryNFT = await notaryNFTInstance.deployed()
    log('  - NotaryNFT:         ', notaryNFT.address);

    const xDRACE = await ethers.getContractFactory('xDRACE');
    const xdrace = await xDRACE.attach(xdraceAddress)
    log('  - xDRACE:         ', xdrace.address);

    log('  - Initializing  DeathRoadNFT        ');
    await deathRoadNFT.setFactory(factoryV2.address)
    await masterchef.setFactory(factoryV2.address)

    await factoryV2.setOldFactory(oldFactory)
    await factoryV2.setXDRACE(xdraceAddress)
    await xdrace.setMinter(factoryV2.address, true)

    log('  - Adding approver ');
    await factoryV2.addApprover('0x75785F9CE180C951c8178BABadFE904ec883D820', true);
    await factoryV2.setSettleFeeReceiver("0xD0e3376e1c3Af2C11730aA4E89BE839D4a1BD761")

    //deploying fee distribution

    log('  - Initializing  NFTFactory        ');
    await factoryV2.initialize(deathRoadNFT.address, draceAddress, feeReceiver, notaryNFT.address, NFTStorageAddress, masterchef.address)

    deployData['NotaryNFT'] = {
      abi: getContractAbi('NotaryNFT'),
      address: notaryNFT.address,
      deployTransaction: notaryNFT.deployTransaction,
    }

    deployData['NFTFactoryV2'] = {
      abi: getContractAbi('NFTFactoryV2'),
      address: factoryV2.address,
      deployTransaction: factoryV2.deployTransaction,
    }

    saveDeploymentData(chainId, deployData);
    log('\n  Contract Deployment Data saved to "deployments" directory.');

    log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n');
  };
  
  module.exports.tags = ['factoryv2']
  