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
  log('DeathRoad GameV3 deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying GameControlV3 Contract...')
  if (parseInt(chainId) == 31337) return

  //reading DRACE token address
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE.json`).address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`)
    .address

  const masterChefAddress = require(`../deployments/${chainId}/MasterChefV2.json`).address

  const GameControlV3 = await ethers.getContractFactory('GameControlV3')
  const gameControlInstance = await GameControlV3.deploy()
  const gameControl = await gameControlInstance.deployed()
  log('  - GameControlV3:         ', gameControl.address)

  deployData['GameControlV3'] = {
    abi: getContractAbi('GameControlV3'),
    address: gameControl.address,
    deployTransaction: gameControl.deployTransaction,
  }

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

  log('  Deploying Referral Contract...')
  const ReferralContract = await ethers.getContractFactory('ReferralContract')
  const ReferralContractInstance = await ReferralContract.deploy()
  const referral = await ReferralContractInstance.deployed()
  log('  - ReferralContract:         ', referral.address)

  deployData['ReferralContract'] = {
    abi: getContractAbi('ReferralContract'),
    address: referral.address,
    deployTransaction: referral.deployTransaction,
  }
  await referral.initialize(masterChefAddress)

  log('  - Initializing  GameControl        ')
  await gameControl.initialize(
    draceAddress,
    DeathRoadNFTAddress,
    constants.getApprover(chainId),
    draceRewardLocker.address,
    xdraceAddress,
    feeReceiver,
    xdraceRewardLocker.address,
    referral.address
  , {gasLimit: 2000000})

  log('  - Adding approver        ')

  await gameControl.addApprover(constants.getApprover(chainId), true, {gasLimit: 200000})
  log('  - Setting minter and locker        ')
  //settings
  const xDRACE = await ethers.getContractFactory('xDRACE')
  const xdraceContract = await xDRACE.attach(xdraceAddress)
  await xdraceContract.setMinter(gameControl.address, true)

  await draceRewardLocker.setLockers([gameControl.address], true)
  await xdraceRewardLocker.setLockers([gameControl.address], true)
  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['gamev3']
