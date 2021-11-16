const {
  chainNameById,
  chainIdByName,
  saveDeploymentData,
  getContractAbi,
  log,
  sleepFor,
} = require('../js-helpers/deploy')
const { upgrades } = require('hardhat')
const _ = require('lodash')
const constants = require('../js-helpers/constants')
const PancakeFactoryABI = require('../abi/IPancakeFactory.json')
const PancakeRouterABI = require('../abi/IPancakeRouter02.json')

module.exports = async (hre) => {
  const { ethers, getNamedAccounts } = hre
  const { deployer } = await getNamedAccounts()
  const network = await hre.network
  const deployData = {}

  const signers = await ethers.getSigners()
  const chainId = chainIdByName(network.name)

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~')
  log(' xDRACEV2 token deployment')
  log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')

  log('  Using Network: ', chainNameById(chainId))
  log('  Using Accounts:')
  log('  - Deployer:          ', signers[0].address)
  log('  - network id:          ', chainId)
  log(' ')

  if (parseInt(chainId) == 31337) return
  const uniswapRouteAddress = constants.getRouter(chainId)

  log('Deploying LiquidityAdder...')
  const LiquidityAdder = await ethers.getContractFactory('LiquidityAdding')
  const liquidityAdderInstance = await LiquidityAdder.deploy()
  const liquidityAdder = await liquidityAdderInstance.deployed()
  log('LiquidityAdder address : ', liquidityAdder.address)

  await liquidityAdder.setWhitelist([signers[0].address], true)

  log('  Deploying xDRACE2 Token...')
  const xDRACE2 = await ethers.getContractFactory('xDRACE2')
  const xdrace2 = await upgrades.deployProxy(
    xDRACE2,
    [liquidityAdder.address],
    { unsafeAllow: ['delegatecall'], kind: 'uups', gasLimit: 1000000 },
  )
  await liquidityAdder.initialize(xdrace2.address, uniswapRouteAddress)
  log('  - xDRACE2:         ', xdrace2.address)

  //create liqidity pair
  let pairedToken = constants.getPairedToken(chainId)
  let router = await ethers.getContractAt(PancakeRouterABI, uniswapRouteAddress)
  let factoryAddress = await router.factory()
  let factory = await ethers.getContractAt(PancakeFactoryABI, factoryAddress)
  await factory.createPair(xdrace2.address, pairedToken)
  await sleepFor(5000)
  let pairAddress = await factory.getPair(xdrace2.address, pairedToken)
  log('Pair', pairAddress)
  await liquidityAdder.setLiquidityPair(pairAddress)
  await xdrace2.setPancakePairs([pairAddress], true)

  deployData['xDRACE2'] = {
    abi: getContractAbi('xDRACE2'),
    address: xdrace2.address,
    deployTransaction: xdrace2.deployTransaction,
  }
  deployData['LiquidityAdding'] = {
    abi: getContractAbi('LiquidityAdding'),
    address: liquidityAdder.address,
    deployTransaction: liquidityAdder.deployTransaction,
  }

  saveDeploymentData(chainId, deployData)
  log('\n  Contract Deployment Data saved to "deployments" directory.')

  log('\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n')
}

module.exports.tags = ['xdrace2']
