const { expect } = require('chai')
const { ethers } = require('hardhat')
const signer = require('./signer')
const deployUtil = require('./deployUtil')

describe('MasterChef', async function () {
  const [
    owner,
    user,
    nftStaker1,
    nftStaker2,
    staker1,
    staker2,
  ] = await ethers.getSigners()
  var drace,
    deathRoadNFT,
    factory,
    featureNames,
    featureValues,
    featureNamesEncode,
    featureValuesSetEncode,
    ufeatureValues,
    ufeatureNamesEncode,
    ufeatureValuesSetEncode,
    nftStorage
  let tokenIds
  let pointMapping = {}
  let masterChef
  let nftStakingPoint
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
      nftStorage
    ] = await deployUtil.deploy(user)
    tokenIds.forEach((id) => {
      pointMapping[id] = id * 100
    })

    const MasterChef = await ethers.getContractFactory('MasterChef')
    const MasterChefInstance = await MasterChef.deploy()
    masterChef = await MasterChefInstance.deployed()

    const NFTStakingPoint = await ethers.getContractFactory('NFTStakingPoint')
    const NFTStakingPointInstance = await NFTStakingPoint.deploy()
    nftStakingPoint = await NFTStakingPointInstance.deployed()

    await masterChef.initialize(
      factory.address,
      deathRoadNFT.address,
      drace.address,
      nftStakingPoint.address,
      ethers.utils.parseEther('100'),
      0,
      100,
    )

    await factory.setMasterChef(masterChef.address)

    await deathRoadNFT
      .connect(user)
      .transferFrom(user.address, nftStaker1.address, tokenIds[0])
    await deathRoadNFT
      .connect(user)
      .transferFrom(user.address, nftStaker1.address, tokenIds[1])
    await deathRoadNFT
      .connect(user)
      .transferFrom(user.address, nftStaker2.address, tokenIds[2])
  })

  it('Deposit NFTs', async function () {
    await deathRoadNFT
      .connect(nftStaker1)
      .setApprovalForAll(masterChef.address, true)
    await deathRoadNFT
      .connect(nftStaker2)
      .setApprovalForAll(masterChef.address, true)

    expect(await factory.boxRewards(nftStaker1.address)).to.equal(0)
    expect(await factory.boxRewards(nftStaker2.address)).to.equal(0)

    await masterChef.connect(nftStaker1).depositNFT([tokenIds[0]])
    await masterChef.connect(nftStaker1).depositNFT([tokenIds[1]])
    await masterChef.connect(nftStaker2).depositNFT([tokenIds[2]])

    expect(await deathRoadNFT.ownerOf(tokenIds[0])).to.be.equal(masterChef.address)
    expect(await deathRoadNFT.ownerOf(tokenIds[1])).to.be.equal(masterChef.address)
    expect(await deathRoadNFT.ownerOf(tokenIds[2])).to.be.equal(masterChef.address)

    //claim with exception
    await expect(masterChef.connect(nftStaker1).claimRewards(0)).to.be.revertedWith('claimRewards: must not be NFT pool')
    await expect(masterChef.connect(nftStaker2).claimRewards(0)).to.be.revertedWith('claimRewards: must not be NFT pool')

    await expect(masterChef.connect(nftStaker1).claimRewardsNFTPool()).to.be.revertedWith('Can only claim rewards after 12hs of stake')
    await expect(masterChef.connect(nftStaker2).claimRewardsNFTPool()).to.be.revertedWith('Can only claim rewards after 12hs of stake')

    expect(await masterChef.pendingDRACE(0, nftStaker1.address)).to.not.equal(0)
    expect(await masterChef.pendingDRACE(0, nftStaker2.address)).to.not.equal(0)

    //withdraw early, rewards is reset
    await expect(masterChef.connect(nftStaker1).withdrawNFT()).to.be.revertedWith('withdrawNFT: NFTs only available for withdrawal after deposit locked time')
    await expect(masterChef.connect(nftStaker2).withdrawNFT()).to.be.revertedWith('withdrawNFT: NFTs only available for withdrawal after deposit locked time')

    expect(await masterChef.pendingDRACE(0, nftStaker1.address)).to.not.equal(0)
    expect(await masterChef.pendingDRACE(0, nftStaker2.address)).to.not.equal(0)

    await masterChef.setRewardPerBlock(ethers.utils.parseEther('50'), true)
    //increase 12h
    await ethers.provider.send('evm_increaseTime', [12 * 3600]);
    
    await masterChef.connect(nftStaker1).withdrawNFT();
    await masterChef.connect(nftStaker2).withdrawNFT();

    expect(await factory.boxRewards(nftStaker1.address)).to.not.equal(0)
    expect(await factory.boxRewards(nftStaker2.address)).to.not.equal(0)

    //check nft owner
    expect(await deathRoadNFT.ownerOf(1)).to.be.equal(nftStaker1.address)
    expect(await deathRoadNFT.ownerOf(2)).to.be.equal(nftStaker1.address)
    expect(await deathRoadNFT.ownerOf(3)).to.be.equal(nftStaker2.address)

    //deposit again
    await masterChef.connect(nftStaker1).depositNFT([tokenIds[0], tokenIds[1]])
    await masterChef.connect(nftStaker2).depositNFT([tokenIds[2]])

    await masterChef.setLockedTime(0)
    await masterChef.connect(nftStaker2).claimRewardsNFTPool()
    await masterChef.setLockedTime(12 * 3600)

    
    await drace.transfer(staker1.address, ethers.utils.parseEther('1000'))
    await drace.transfer(staker2.address, ethers.utils.parseEther('2000'))

    await drace.connect(staker1).approve(masterChef.address, ethers.utils.parseEther('1000'))
    await drace.connect(staker2).approve(masterChef.address, ethers.utils.parseEther('2000'))

    await masterChef.connect(staker1).deposit(1, ethers.utils.parseEther('1000'))
    await masterChef.setRewardPerBlock(ethers.utils.parseEther('50'), true)

    await masterChef.connect(staker2).deposit(1, ethers.utils.parseEther('2000'))
    await masterChef.setRewardPerBlock(ethers.utils.parseEther('100'), true)

    expect(await drace.balanceOf(staker1.address)).to.be.equal(0)
    expect(await drace.balanceOf(staker2.address)).to.be.equal(0)

    await ethers.provider.send('evm_mine');

    expect(await masterChef.pendingDRACE(1, staker1.address)).to.not.equal(0)
    expect(await masterChef.pendingDRACE(1, staker2.address)).to.not.equal(0)

    expect(await factory.boxRewards(staker1.address)).to.be.equal(0)
    expect(await factory.boxRewards(staker2.address)).to.be.equal(0)

    await masterChef.connect(staker1).claimRewards(1)
    await masterChef.connect(staker2).claimRewards(1)

    expect(await factory.boxRewards(staker1.address)).to.not.equal(0)
    expect(await factory.boxRewards(staker2.address)).to.not.equal(0)

    await ethers.provider.send('evm_increaseTime', [12 * 3600]);

    //withdraw all
    await masterChef.connect(staker1).withdraw(1, ethers.utils.parseEther('1000'))
    await masterChef.connect(staker2).withdraw(1, ethers.utils.parseEther('2000'))

    await expect(masterChef.connect(staker1).withdrawNFT()).to.be.revertedWith('withdrawNFT: not good');
    await expect(masterChef.connect(staker2).withdrawNFT()).to.be.revertedWith('withdrawNFT: not good');

    await masterChef.connect(nftStaker1).withdrawNFT();
    await masterChef.connect(nftStaker2).withdrawNFT();

    expect(await drace.balanceOf(staker1.address)).to.be.equal(ethers.utils.parseEther('1000'))
    expect(await drace.balanceOf(staker2.address)).to.be.equal(ethers.utils.parseEther('2000'))

    expect(await deathRoadNFT.ownerOf(tokenIds[0])).to.be.equal(nftStaker1.address)
    expect(await deathRoadNFT.ownerOf(tokenIds[1])).to.be.equal(nftStaker1.address)
    expect(await deathRoadNFT.ownerOf(tokenIds[2])).to.be.equal(nftStaker2.address)

    expect(await factory.boxRewards(staker1.address)).to.not.equal(0)
    expect(await factory.boxRewards(staker2.address)).to.not.equal(0)
  })

  it('Deposit Bad Feature NFTs, none allocated point', async function () {
    await deathRoadNFT
      .connect(nftStaker1)
      .setApprovalForAll(masterChef.address, true)
    await deathRoadNFT
      .connect(nftStaker2)
      .setApprovalForAll(masterChef.address, true)

    //minting bad nft features
    let featureNames = ["pack1", "type"]
    let featureValues = [["1star", "car"], ["2star", "car"], ["3star", "car"]]
    let featureNamesEncode = [signer.encodeString(featureNames[0]), signer.encodeString(featureNames[1])]
    let featureValuesSetEncode = [
        [signer.encodeString(featureValues[0][0]), signer.encodeString(featureValues[0][1])],
        [signer.encodeString(featureValues[1][0]), signer.encodeString(featureValues[1][1])],
        [signer.encodeString(featureValues[2][0]), signer.encodeString(featureValues[2][1])]
    ]

    await factory.mint(nftStaker1.address, featureNamesEncode, featureValuesSetEncode[0])

    await expect(masterChef.connect(nftStaker1).depositNFT([4])).to.be.not.revertedWith('Deposit Bad Feature NFTs, none allocated point')
  })
})
