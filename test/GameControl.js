const { expect } = require('chai')
const { ethers } = require('hardhat')
const signer = require('./signer')
const deployUtil = require('./deployUtil')

function toWei(n) {
  return ethers.utils.parseEther(n)
}

describe('Game Control', async function () {
  const [owner, player, feeTo] = await ethers.getSigners()
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
  let xDrace
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
    await tokenVesting.initialize(drace.address, 0)

    const NFTCountdown = await ethers.getContractFactory('NFTCountdown')
    const nftCountdownInstance = await NFTCountdown.deploy()
    nftCountDown = await nftCountdownInstance.deployed()

    const xDRACE = await ethers.getContractFactory('xDRACE')
    const xDRACEInstance = await xDRACE.deploy()
    xDrace = await xDRACEInstance.deployed()

    await gameControl.initialize(
      drace.address,
      deathRoadNFT.address,
      signer.signerAddress,
      tokenVesting.address,
      nftCountDown.address,
      factory.address,
      xDrace.address,
      feeTo.address
    )

    await xDrace.setMinter(gameControl.address, true)
    await tokenVesting.setLockers([gameControl.address], true)
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
    for(const i of tokenIds) {
      await gameControl.connect(player).withdrawNFT(i)
    }

    for (var i = 0; i < tokenIds.length; i++) {
      expect(await deathRoadNFT.ownerOf(tokenIds[i])).to.be.equal(
        player.address,
      )
      const depositInfo = await gameControl.tokenDeposits(tokenIds[i])
      expect(depositInfo.depositor).to.be.equal(ethers.constants.AddressZero)
      expect(depositInfo.tokenId).to.be.equal(0)
    }
  }

  async function withdrawAllNFTs(player) {
    await gameControl.connect(player).withdrawAllNFTs()

    for (var i = 0; i < tokenIds.length; i++) {
      expect(await deathRoadNFT.ownerOf(tokenIds[i])).to.be.equal(
        player.address,
      )
      const depositInfo = await gameControl.tokenDeposits(tokenIds[i])
      expect(depositInfo.depositor).to.be.equal(ethers.constants.AddressZero)
      expect(depositInfo.tokenId).to.be.equal(0)
    }
  }

  function assertArray(arr1, arr2) {
    expect(arr1.length).to.be.equal(arr2.length)
    for(var i = 0;  i < arr1.length; i++) {
      expect(arr1[i]).to.be.equal(arr2[i])
    }
  }

  it('Deposit NFTs & withdraw', async function () {
    await depositNFTs(player, tokenIds)
    let depositList = await gameControl.getDepositTokenList(player.address)
    assertArray(tokenIds, depositList)
    await withdrawNFTs(player, tokenIds)

    await depositNFTs(player, tokenIds)
    await withdrawAllNFTs(player)
  })

  it('Deposit NFTs & withdraw 2 times', async function () {
    await depositNFTs(player, tokenIds)
    await withdrawNFTs(player, tokenIds)
    for(const i of tokenIds) {
      await expect(gameControl.connect(player).withdrawNFT(i)).to.be.revertedWith('withdrawNFT: NFT not yours')
    }
  })

  it('Start game without calling deposit first', async function () {
    await deathRoadNFT
      .connect(player)
      .setApprovalForAll(gameControl.address, true)

    await gameControl.connect(player).startGameMock(tokenIds)
    await checkDeposits(player, tokenIds)
  })

  it('Start game can only be called after countdown', async function () {
    await deathRoadNFT
      .connect(player)
      .setApprovalForAll(gameControl.address, true)

    await nftCountDown.setDefaultCountdown(2 * 3600)

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

  it('Reward Distribution', async function () {
    await drace.transfer(gameControl.address, toWei('100000'))
    await expect(gameControl.distributeRewardMock(toWei('10'), toWei('20'), toWei('10'), [1, 2], false)).to.be.revertedWith('No game id for this recipient')

    //start game
    await deathRoadNFT
      .connect(player)
      .setApprovalForAll(gameControl.address, true)

    await nftCountDown.setDefaultCountdown(2 * 3600)

    await gameControl.connect(player).startGameMock(tokenIds)
    await checkDeposits(player, tokenIds)

    await expect(gameControl.distributeRewardMock(toWei('10'), toWei('20'), toWei('10'), [1, 2], false)).to.be.revertedWith('No game id for this recipient')

    await gameControl.connect(player).distributeRewardMock(toWei('10'), toWei('20'), toWei('10'), [0], false)
    await expect(gameControl.distributeRewardMock(toWei('10'), toWei('20'), toWei('10'), [0], false)).to.be.revertedWith('rewards already paid')

    expect(await drace.balanceOf(tokenVesting.address)).to.be.equal(toWei('10'))
    expect(await xDrace.balanceOf(player.address)).to.be.equal(toWei('20'))
  })
})
