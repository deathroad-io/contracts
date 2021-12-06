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
  log('DeathRoad HPL DAO deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying DeathRoadHPLDAO Contract...')
  if (parseInt(chainId) == 31337) return

  const DeathRoadHPLDAO = await ethers.getContractFactory('DeathRoadHPLDAO')
  const hplDao = await upgrades.deployProxy(
    DeathRoadHPLDAO,
    [constants.getDAOPaymentToken(chainId), constants.getApprover(chainId)],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 2000000 },
  )
  log('  - DeathRoadHPLDAO:         ', hplDao.address)

  deployData['DeathRoadHPLDAO'] = {
    abi: getContractAbi('DeathRoadHPLDAO'),
    address: hplDao.address,
    deployTransaction: hplDao.deployTransaction,
  }

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['hpldao']
