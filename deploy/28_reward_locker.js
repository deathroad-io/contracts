const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
} = require('../js-helpers/deploy')

const _ = require('lodash')
let feeReceiver = '0xd91ce559ab85e32169462BB39739E4ED8babb6FE'
const constants = require('../js-helpers/constants')
module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log('DeathRoad RewardLocker deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying RewardLocker Contract...')
  if (parseInt(chainId) == 31337) return

  //reading DRACE token address
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE2.json`).address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`)
    .address
  const GameControlV4Address = require(`../deployments/${chainId}/GameControlV4.json`).address

  const DraceRewardLocker = await ethers.getContractFactory('DraceRewardLocker')
  const draceRewardLocker = await upgrades.deployProxy(
    DraceRewardLocker,
    [draceAddress, 0],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 2000000 },
  )
  log('  - DraceRewardLocker:         ', draceRewardLocker.address)

  deployData['DraceRewardLocker'] = {
    abi: getContractAbi('DraceRewardLocker'),
    address: draceRewardLocker.address,
    deployTransaction: draceRewardLocker.deployTransaction,
  }

  const xDraceRewardLocker = await ethers.getContractFactory('xDraceRewardLocker')
  const xdraceRewardLocker = await upgrades.deployProxy(
    xDraceRewardLocker,
    [xdraceAddress, 0],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 2000000 },
  )
  log('  - xDraceRewardLocker:         ', xdraceRewardLocker.address)

  deployData['xDraceRewardLocker'] = {
    abi: getContractAbi('xDraceRewardLocker'),
    address: xdraceRewardLocker.address,
    deployTransaction: xdraceRewardLocker.deployTransaction,
  }

  if (chainId == 56) {
    feeReceiver = require(`../deployments/${chainId}/RevenueDistributor.json`).address
  }

  const GameControlV4 = await ethers.getContractFactory('GameControlV4')
  const gameControl = await GameControlV4.attach(GameControlV4Address)

  log('  - GameControlV4:         ', gameControl.address)

  //settings
  const xDRACE = await ethers.getContractFactory('xDRACE2')
  const xdraceContract = await xDRACE.attach(xdraceAddress)
  await xdraceContract.setMinters([gameControl.address], true, {gasLimit: 200000})

  await draceRewardLocker.setLockers([gameControl.address], true, {gasLimit: 200000})
  await xdraceRewardLocker.setLockers([gameControl.address], true, {gasLimit: 200000})

  await gameControl.setTokenVesting(draceRewardLocker.address)
  await gameControl.setXDraceVesting(xdraceRewardLocker.address)
  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['rewardlockerupgradeabledeploy']
