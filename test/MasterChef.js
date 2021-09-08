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
    ufeatureValuesSetEncode
  let tokenIds
  let pointMapping = {}
  let masterChef
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
    ] = await deployUtil.deploy(user)
    tokenIds.forEach((id) => {
      pointMapping[id] = id * 100
    })

    const MasterChefMock = await ethers.getContractFactory('MasterChefMock')
    const MasterChefMockInstance = await MasterChefMock.deploy()
    masterChef = await MasterChefMockInstance.deployed()

    await masterChef.initialize(
      factory.address,
      deathRoadNFT.address,
      drace.address,
      ethers.constants.AddressZero,
      ethers.utils.parseEther('100'),
      0,
      100,
    )

    await factory.setMasterChef(masterChef.address)
    await drace.transfer(staker1.address, ethers.utils.parseEther('1000'))
    await drace.transfer(staker2.address, ethers.utils.parseEther('1000'))

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

    
    await masterChef.connect(nftStaker1).depositNFTMock(tokenIds[0], 100)
    await masterChef.connect(nftStaker1).depositNFTMock(tokenIds[1], 200)

    await masterChef.connect(nftStaker2).depositNFTMock(tokenIds[2], 300)

    

    await masterChef.connect(nftStaker1).claimRewards(0)
    await masterChef.connect(nftStaker2).claimRewards(0)

    expect(await factory.boxRewards(nftStaker1.address)).to.not.equal(0)
    expect(await factory.boxRewards(nftStaker2.address)).to.not.equal(0)
  })
})
