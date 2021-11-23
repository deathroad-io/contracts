const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
} = require('../js-helpers/deploy')

const _ = require('lodash')
const feeReceiver = '0xd91ce559ab85e32169462BB39739E4ED8babb6FE'
const constants = require('../js-helpers/constants')
module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log('DeathRoad NFT Factory V3 deployment')
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
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE2.json`)
    .address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`)
    .address
  const NFTStorageAddress = require(`../deployments/${chainId}/NFTStorage.json`)
    .address
  const MasterChefAddress = require(`../deployments/${chainId}/MasterChef.json`)
    .address
  const MasterChefV2Address = require(`../deployments/${chainId}/MasterChefV2.json`)
    .address
  const oldFactory = require(`../deployments/${chainId}/NFTFactory.json`)
    .address
  const factoryV2 = require(`../deployments/${chainId}/NFTFactoryV2.json`)
    .address
  const nftNotaryAddress = require(`../deployments/${chainId}/NotaryNFT.json`)
    .address
  const xDraceDistributorAddress = require(`../deployments/${chainId}/xDraceDistributor.json`)
    .address

  // const GameControlAddress = require(`../deployments/${chainId}/GameControl.json`)
  //   .address

  const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT')
  const deathRoadNFT = await DeathRoadNFT.attach(DeathRoadNFTAddress)
  log('  - DeathRoadNFT:         ', deathRoadNFT.address)

  const MasterChef = await ethers.getContractFactory('MasterChef')
  const masterchef = await MasterChef.attach(MasterChefAddress)

  const masterchefV2 = await MasterChef.attach(MasterChefV2Address)

  log('  Deploying NFT Factoryv3 Contract...')
  const NFTFactoryV3 = await ethers.getContractFactory('NFTFactoryV3')

  const factoryV3 = await upgrades.upgradeProxy(
    '0xa82Dd4821e3715fb4728F69F1926418CDfAC1Ccd',
    NFTFactoryV3,
    [
      deathRoadNFT.address,
      draceAddress,
      feeReceiver,
      nftNotaryAddress,
      NFTStorageAddress,
      masterchefV2.address,
      xDraceDistributorAddress,
      xdraceAddress,
    ],
    {
      unsafeAllow: ['delegatecall'],
      unsafeAllowCustomTypes: true,
      kind: 'uups',
      gasLimit: 1000000,
    },
  )

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['factoryv3upgrade']
