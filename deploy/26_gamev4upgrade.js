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
  log('DeathRoad GameV4 deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Upgrade GameControlV4 Contract...')
  if (parseInt(chainId) == 31337) return

  //reading DRACE token address
  const GameControlV4Address = require(`../deployments/${chainId}/GameControlV4.json`).address
  
  const GameControlV4Upgraded = await ethers.getContractFactory('GameControlV4Upgraded')
  console.log('GameControlV4Address', GameControlV4Address)
  await upgrades.upgradeProxy(
    GameControlV4Address,
    GameControlV4Upgraded,
    [
      GameControlV4Address,
      GameControlV4Address,
      GameControlV4Address,
      GameControlV4Address,
      GameControlV4Address,
      GameControlV4Address,
      GameControlV4Address,
      GameControlV4Address
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

module.exports.tags = ['gamev4upgrade']
