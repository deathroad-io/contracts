const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
} = require('../js-helpers/deploy')

const _ = require('lodash')
const constants = require('../js-helpers/constants')
module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log('DeathRoad Reward Claim deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying RewardClaim Contract...')
  if (parseInt(chainId) == 31337) return

  //reading DRACE token address
  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const xdraceAddress = require(`../deployments/${chainId}/xDRACE2.json`)
    .address
  const DraceRewardLockerAddress = require(`../deployments/${chainId}/DraceRewardLocker.json`)
    .address
  const xDraceRewardLockerAddress = require(`../deployments/${chainId}/xDraceRewardLocker.json`)
    .address
  const ReferralContractAddress = require(`../deployments/${chainId}/ReferralContract.json`)
    .address
  const liquidityAddingAddress = require(`../deployments/${chainId}/LiquidityAdding.json`)
    .address
  const rewardClaimAddress = require(`../deployments/${chainId}/RewardClaim.json`)
    .address

  const DraceRewardLocker = await ethers.getContractFactory('DraceRewardLocker')
  const draceRewardLocker = await DraceRewardLocker.attach(
    DraceRewardLockerAddress,
  )

  const xDraceRewardLocker = await ethers.getContractFactory(
    'xDraceRewardLocker',
  )
  const xdraceRewardLocker = await xDraceRewardLocker.attach(
    xDraceRewardLockerAddress,
  )

  const RewardClaim = await ethers.getContractFactory('RewardClaim')

  await upgrades.upgradeProxy(
    rewardClaimAddress,
    RewardClaim,
    [
      draceAddress,
      constants.getApprover(chainId),
      draceRewardLocker.address,
      xdraceAddress,
      xdraceRewardLocker.address,
      ReferralContractAddress,
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

module.exports.tags = ['rewardclaimupgrade']
