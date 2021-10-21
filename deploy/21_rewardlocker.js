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
  log('DeathRoad Game Reward Locker deployment')
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
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE.json`).address
  const GameControlV3Address = require(`../deployments/${chainId}/GameControlV3.json`).address

  const DraceRewardLocker = await ethers.getContractFactory('DraceRewardLocker')
  const DraceRewardLockerInstance = await DraceRewardLocker.deploy()
  const draceRewardLocker = await DraceRewardLockerInstance.deployed()
  log('  - DraceRewardLocker:         ', draceRewardLocker.address)

  deployData['DraceRewardLocker'] = {
    abi: getContractAbi('DraceRewardLocker'),
    address: draceRewardLocker.address,
    deployTransaction: draceRewardLocker.deployTransaction,
  }
  await draceRewardLocker.initialize(draceAddress, 0)

  const xDraceRewardLocker = await ethers.getContractFactory('xDraceRewardLocker')
  const xDraceRewardLockerInstance = await xDraceRewardLocker.deploy()
  const xdraceRewardLocker = await xDraceRewardLockerInstance.deployed()
  log('  - xDraceRewardLocker:         ', xdraceRewardLocker.address)

  deployData['xDraceRewardLocker'] = {
    abi: getContractAbi('xDraceRewardLocker'),
    address: xdraceRewardLocker.address,
    deployTransaction: xdraceRewardLocker.deployTransaction,
  }
  await xdraceRewardLocker.initialize(xdraceAddress, 0)

  const GameControlV3 = await ethers.getContractFactory('GameControlV3')
  const gameControl = await GameControlV3.attach(GameControlV3Address)

  log('  - Changing reward locker        ')
  await gameControl.setTokenVesting(draceRewardLocker.address)
  await gameControl.setXDraceVesting(xdraceRewardLocker.address)

  log('  - Setting minter and locker        ')
  await draceRewardLocker.setLockers([gameControl.address], true)
  await xdraceRewardLocker.setLockers([gameControl.address], true)
  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['gamerewardlocker']
