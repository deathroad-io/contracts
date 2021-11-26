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
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE2.json`).address
  const DeathRoadNFTAddress = require(`../deployments/${chainId}/DeathRoadNFT.json`)
    .address
  const liquidityAddingAddress = require(`../deployments/${chainId}/LiquidityAdding.json`).address
  const masterChefAddress = require(`../deployments/${chainId}/MasterChefV2.json`).address

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

  if (chainId == 56) {
    feeReceiver = require(`../deployments/${chainId}/RevenueDistributor.json`).address
  }

  const GameControlV4 = await ethers.getContractFactory('GameControlV4')
  const gameControl = await upgrades.deployProxy(
    GameControlV4,
    [draceAddress, DeathRoadNFTAddress, constants.getApprover(chainId), draceRewardLocker.address, xdraceAddress, feeReceiver, xdraceRewardLocker.address, referral.address],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )

  log('  - GameControlV4:         ', gameControl.address)

  deployData['GameControlV4'] = {
    abi: getContractAbi('GameControlV4'),
    address: gameControl.address,
    deployTransaction: gameControl.deployTransaction,
  }

  log('  - Adding approver        ')

  await gameControl.addApprover(constants.getApprover(chainId), true, {gasLimit: 200000})
  log('  - Setting minter and locker        ')
  //settings
  const xDRACE = await ethers.getContractFactory('xDRACE2')
  const xdraceContract = await xDRACE.attach(xdraceAddress)
  await xdraceContract.setMinters([gameControl.address], true, {gasLimit: 200000})

  await draceRewardLocker.setLockers([gameControl.address], true, {gasLimit: 200000})
  await xdraceRewardLocker.setLockers([gameControl.address], true, {gasLimit: 200000})

  const LiquidityAdding = await ethers.getContractFactory('LiquidityAdding')
  const liquidityAdding = await LiquidityAdding.attach(liquidityAddingAddress)
  await liquidityAdding.setWhitelist([xdraceRewardLocker.address], true)

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['gamev4']
