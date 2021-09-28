const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
} = require('../js-helpers/deploy')

const _ = require('lodash')
const feeReceiver = '0xd91ce559ab85e32169462BB39739E4ED8babb6FE'
const constants = require('./constants')
module.exports = async (hre) => {
  const { ethers, getNamedAccounts, upgrades } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log('DeathRoad NFT Factory deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying NFT FactoryV2 Contract...')
  if (parseInt(chainId) == 31337) return
  //reading DRACE token address
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE.json`).address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`)
    .address
  const NFTStorageAddress = require(`../deployments/${chainId}/NFTStorage.json`)
    .address
  const MasterChefAddress = require(`../deployments/${chainId}/MasterChef.json`)
    .address
  const oldFactory = require(`../deployments/${chainId}/NFTFactory.json`)
    .address

  const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT')
  const deathRoadNFT = await DeathRoadNFT.attach(DeathRoadNFTAddress)
  log('  - DeathRoadNFT:         ', deathRoadNFT.address)

  const MasterChef = await ethers.getContractFactory('MasterChef')
  const masterchef = await MasterChef.attach(MasterChefAddress)
  log('  - DeathRoadNFT:         ', deathRoadNFT.address)

  log('  Deploying NFT Factoryv2 Contract...')
  const NFTFactoryV2 = await ethers.getContractFactory('NFTFactoryV2')
  const mc = await upgrades.deployProxy(NFTFactoryV2)
  //const nftFactoryV2Instance = await NFTFactoryV2.deploy()
  const factoryV2 = await mc.deployed()
  log('  - NFTFactoryV2:         ', factoryV2.address)

  log('  Deploying NFT Notary Contract...')
  const NotaryNFT = await ethers.getContractFactory('NotaryNFT')
  const notaryNFTInstance = await NotaryNFT.deploy()
  const notaryNFT = await notaryNFTInstance.deployed()
  log('  - NotaryNFT:         ', notaryNFT.address)

  const xDRACE = await ethers.getContractFactory('xDRACE')
  const xdrace = await xDRACE.attach(xdraceAddress)
  log('  - xDRACE:         ', xdrace.address)

  log('  - Initializing  DeathRoadNFT        ')
  await deathRoadNFT.setFactory(factoryV2.address)
  log('  - masterchef  setFactory        ')
  await masterchef.setFactory(factoryV2.address)

  await factoryV2.setOldFactory(oldFactory)
  await factoryV2.setXDRACE(xdraceAddress)
  log('  - setMinter        ')
  await xdrace.setMinter(factoryV2.address, true)

  log('  - Adding approver ')
  await factoryV2.addApprover(
    constants.getApprover(chainId),
    true,
  )
  await factoryV2.setSettleFeeReceiver(
    constants.getSettler(chainId)
  )

  const xDraceDistributor = await ethers.getContractFactory('xDraceDistributor')
  const xDraceDistributorInstance = await xDraceDistributor.deploy()
  const xdraceDistributor = await xDraceDistributorInstance.deployed()
  log('  - xDraceDistributor:         ', xdraceDistributor.address)
  //30 days vesting for coverted xdrace
  await xdraceDistributor.initialize(xdraceAddress, 30 * 86400)
  await xdraceDistributor.setLockers([factoryV2.address], true)
  //deploying fee distribution

  log('  - Initializing  NFTFactory        ')
  await factoryV2.initialize(
    deathRoadNFT.address,
    draceAddress,
    feeReceiver,
    notaryNFT.address,
    NFTStorageAddress,
    masterchef.address,
    xdraceDistributor.address,
    xdraceAddress,
  )

  deployData['xDraceDistributor'] = {
    abi: getContractAbi('xDraceDistributor'),
    address: xdraceDistributor.address,
    deployTransaction: xdraceDistributor.deployTransaction,
  }

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

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['factoryv2upgradable']
