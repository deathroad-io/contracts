const { expect } = require('chai')
const { ethers } = require('hardhat')
const signer = require('./signer')
const deployUtil = require('./deployUtil')

describe('Game Control', async function () {
  const [owner, player] = await ethers.getSigners()
  var drace,
    deathRoadNFT,
    factory,
    featureNames,
    featureValues,
    featureNamesEncode,
    featureValuesSetEncode,
    ufeatureValues,
    ufeatureNamesEncode,
    ufeatureValuesSetEncode
  let tokenIds
  let gameControl
  let nftCountDown
  beforeEach(async () => {
    ;[
      drace,
      deathRoadNFT,
      factory,
      featureNames,
      featureValues,
      featureNamesEncode,
      featureValuesSetEncode,
      ufeatureValues,
      ufeatureNamesEncode,
      ufeatureValuesSetEncode,
      tokenIds,
    ] = await deployUtil.deploy(player)
    let GameControl = await ethers.getContractFactory('GameControlMock')
    let GameControlInstance = await GameControl.deploy()
    gameControl = await GameControlInstance.deployed()

    let TokenVesting = await ethers.getContractFactory('TokenVesting')
    let TokenVestingInstance = await TokenVesting.deploy()
    tokenVesting = await TokenVestingInstance.deployed()
    await tokenVesting.initialize(drace.address, 2 * 86400)

    const NFTCountdown = await ethers.getContractFactory('NFTCountdown')
    const nftCountdownInstance = await NFTCountdown.deploy()
    const nftCountDown = await nftCountdownInstance.deployed()

    await gameControl.initialize(
      drace.address,
      deathRoadNFT.address,
      signer.signerAddress,
      tokenVesting.address,
      nftCountDown.address,
    )
  })

  async function depositNFTs(player, tokenIds) {
    await deathRoadNFT
      .connect(player)
      .setApprovalForAll(gameControl.address, true)
    await gameControl.connect(player).depositNFTsToPlay(tokenIds)

    //checking token ownership
    await checkDeposits(player, tokenIds)
  }

  async function checkDeposits(player, tokenIds) {
    //checking token ownership
    for (var i = 0; i < tokenIds.length; i++) {
      expect(await deathRoadNFT.ownerOf(tokenIds[i])).to.be.equal(
        gameControl.address,
      )
      const depositInfo = await gameControl.tokenDeposits(tokenIds[i])
      expect(depositInfo.depositor).to.be.equal(player.address)
      expect(depositInfo.tokenId).to.be.equal(tokenIds[i])
    }
  }

  async function withdrawNFTs(player, tokenIds) {
    await gameControl.connect(player).withdrawNFTs(tokenIds)

    for (var i = 0; i < tokenIds.length; i++) {
      expect(await deathRoadNFT.ownerOf(tokenIds[i])).to.be.equal(
        player.address,
      )
      const depositInfo = await gameControl.tokenDeposits(tokenIds[i])
      expect(depositInfo.depositor).to.be.equal(ethers.constants.AddressZero)
      expect(depositInfo.tokenId).to.be.equal(0)
    }
  }

  it('Deposit NFTs & withdraw', async function () {
    await depositNFTs(player, tokenIds)
    await withdrawNFTs(player, tokenIds)
  })

  it('Deposit NFTs & withdraw 2 times', async function () {
    await depositNFTs(player, tokenIds)
    await withdrawNFTs(player, tokenIds)
    await withdrawNFTs(player, tokenIds)
  })

  it('Start game without calling deposit first', async function () {
    await deathRoadNFT
      .connect(player)
      .setApprovalForAll(gameControl.address, true)

    await gameControl.connect(player).startGameMock(tokenIds)
    await checkDeposits(player, tokenIds)
  })

  it('Start game cal only be called after countdown', async function () {
    await deathRoadNFT
      .connect(player)
      .setApprovalForAll(gameControl.address, true)

    await gameControl.connect(player).startGameMock(tokenIds)
    await checkDeposits(player, tokenIds)

    await expect(gameControl.connect(player).startGameMock(tokenIds)).to.be
      .reverted

    await ethers.provider.send('evm_increaseTime', [2 * 3600])
    await ethers.provider.send('evm_mine')

    await gameControl.connect(player).startGameMock(tokenIds)

    await expect(gameControl.connect(player).startGameMock(tokenIds)).to.be
      .reverted

    await expect(withdrawNFTs(player, tokenIds)).to.be.reverted

    await ethers.provider.send('evm_increaseTime', [2 * 300])
    await ethers.provider.send('evm_mine')

    await withdrawNFTs(player, tokenIds)
  })
})
