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

  log('  Deploying Token Vesting Contract...')
  const TokenVesting = await ethers.getContractFactory('TokenVesting')
  const tokenVestingInstance = await TokenVesting.deploy()
  const tokenVesting = await tokenVestingInstance.deployed()
  log('  - TokenVesting:         ', tokenVesting.address)

  deployData['TokenVesting'] = {
    abi: getContractAbi('TokenVesting'),
    address: tokenVesting.address,
    deployTransaction: tokenVesting.deployTransaction,
  }

  log('  - Initializing  TokenVesting        ')
  await tokenVesting.initialize(draceAddress, 0)

  const xDraceDistributor = await ethers.getContractFactory('xDraceDistributor')
  const xDraceDistributorInstance = await xDraceDistributor.deploy()
  const xdraceDistributor = await xDraceDistributorInstance.deployed()
  log('  - xDraceDistributor:         ', xdraceDistributor.address)
  //game vesting 3 days
  await xdraceDistributor.initialize(xdraceAddress, 3 * 86400)

  deployData['xDraceDistributorGameVesting'] = {
    abi: getContractAbi('xDraceDistributor'),
    address: xdraceDistributor.address,
    deployTransaction: xdraceDistributor.deployTransaction,
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

  log('  - Initializing  GameControl        ')
  await gameControl.initialize(
    draceAddress,
    DeathRoadNFTAddress,
    constants.getApprover(chainId),
    tokenVesting.address,
    xdraceAddress,
    feeReceiver,
    xdraceDistributor.address,
    referral.address
  , {gasLimit: 2000000})

  log('  - Adding approver        ')

  await gameControl.addApprover(constants.getApprover(chainId), true, {gasLimit: 200000})
  log('  - Setting minter and locker        ')
  //settings
  const xDRACE = await ethers.getContractFactory('xDRACE')
  const xdraceContract = await xDRACE.attach(xdraceAddress)
  await xdraceContract.setMinter(gameControl.address, true)
  await tokenVesting.setLockers([gameControl.address], true)
  await xdraceDistributor.setLockers([gameControl.address], true)
  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['gamev3']
