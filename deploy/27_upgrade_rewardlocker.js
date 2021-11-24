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
  log('DeathRoad Upgrade Game Reward deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Upgrade game reward Contract...')
  if (parseInt(chainId) == 31337) return
  const DraceRewardLockerAddress = require(`../deployments/${chainId}/DraceRewardLocker.json`).address
  const xDraceRewardLockerAddress = require(`../deployments/${chainId}/xDraceRewardLocker.json`).address
  console.log(DraceRewardLockerAddress, xDraceRewardLockerAddress
    )
  const DraceRewardLocker = await ethers.getContractFactory('DraceRewardLocker')

  await upgrades.upgradeProxy(
    DraceRewardLockerAddress,
    DraceRewardLocker,
    [
      DraceRewardLockerAddress,
      0
    ],
    {
      unsafeAllow: ['delegatecall'],
      unsafeAllowCustomTypes: true,
      kind: 'uups',
      gasLimit: 1000000,
    },
  )

  const xDraceRewardLocker = await ethers.getContractFactory('xDraceRewardLocker')

  await upgrades.upgradeProxy(
    xDraceRewardLockerAddress,
    xDraceRewardLocker,
    [
      DraceRewardLockerAddress,
      0
    ],
    {
      unsafeAllow: ['delegatecall'],
      unsafeAllowCustomTypes: true,
      kind: 'uups',
      gasLimit: 1000000,
    },
  )

  
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['rewardlockerupgrade']
