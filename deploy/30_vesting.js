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
  log('DeathRoad Vesting deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  log('  Deploying Vesting Contract...')
  if (parseInt(chainId) == 31337) return

  let privateSales = require(`../data/vesting/${chainId}.json`)
  let privateAddresses = []
  let privateAmounts = []
  let total = 0
  for (const p of privateSales) {
    privateAddresses.push(p.address)
    privateAmounts.push(ethers.utils.parseEther(`${p.totalAmount}`))
    total += p.totalAmount
  }
  console.log(total)

  const draceAddress = require(`../deployments/${chainId}/DRACE.json`).address
  const Vesting = await ethers.getContractFactory('Vesting')
  const vesting = await upgrades.deployProxy(Vesting, [draceAddress, 0], {
    unsafeAllow: ['delegatecall'],
    kind: 'uups',
    gasLimit: 2000000,
  })
  log('  - Vesting:         ', vesting.address)

  log('  - Adding vesting         ')

  await vesting.addVesting(privateAddresses, privateAmounts)

  deployData['Vesting'] = {
    abi: getContractAbi('Vesting'),
    address: vesting.address,
    deployTransaction: vesting.deployTransaction,
  }

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')
  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['vesting']
