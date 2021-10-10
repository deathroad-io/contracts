const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
} = require('../js-helpers/deploy')

const _ = require('lodash')

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log('DeathRoad Farming MasterChefV2 Contract deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying Farming Contract...')
  if (parseInt(chainId) == 31337) return
  const MasterChefV2 = await ethers.getContractFactory('MasterChefV2')
  const MasterChefV2Instance = await MasterChefV2.deploy()
  const masterChef = await MasterChefV2Instance.deployed()
  log('  - MasterChef:         ', masterChef.address)
  deployData['MasterChefV2'] = {
    abi: getContractAbi('MasterChefV2'),
    address: masterChef.address,
    deployTransaction: masterChef.deployTransaction,
  }

  log('  Reading NFTStakingPoint Contract...')
  const NFTStakingPointAddress = require(`../deployments/${chainId}/NFTStakingPoint.json`)
    .address
  log('  - NFTStakingPoint:         ', NFTStakingPointAddress)

  const TokenLock = await ethers.getContractFactory('TokenLock')
  const TokenLockInstance = await TokenLock.deploy()
  const tokenLock = await TokenLockInstance.deployed()
  log('  - TokenLock:         ', tokenLock.address)
  log('  Initializing TokenLock Contract...')
  await tokenLock.initialize(masterChef.address)
  deployData['TokenLock'] = {
    abi: getContractAbi('TokenLock'),
    address: tokenLock.address,
    deployTransaction: tokenLock.deployTransaction,
  }

  //initializing
  log('  Initializing Farming Contract...')
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const nftAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`)
    .address
  const factoryAddress = require(`../deployments/${chainId}/NFTFactoryV2.json`)
    .address
  await masterChef.initialize(
    factoryAddress,
    nftAddress,
    draceAddress,
    NFTStakingPointAddress,
    ethers.utils.parseEther('1'),
    0,
    tokenLock.address,
  )

  //set masterchef in factory
  const NFTFactoryV2 = await ethers.getContractFactory('NFTFactoryV2')
  const factoryContract = await NFTFactoryV2.attach(factoryAddress)
  await factoryContract.setMasterChef(masterChef.address)

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['masterchefv2']
