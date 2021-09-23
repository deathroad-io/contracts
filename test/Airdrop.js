const { expect } = require('chai')
const { ethers } = require('hardhat')

function toWei(n) {
    return ethers.utils.parseEther(n)
}

describe('AirdropDistribution', async function () {
  const [owner, claimer1, claimer2] = await ethers.getSigners()
  let drace, airdrop
  beforeEach(async () => {
    const DRACE = await ethers.getContractFactory('DRACE')
    const draceInstance = await DRACE.deploy(owner.address)
    drace = await draceInstance.deployed()

    const AirdropDistributionMock = await ethers.getContractFactory('AirdropDistributionMock')
    const AirdropDistributionMockInstance = await AirdropDistributionMock.deploy()
    airdrop = await AirdropDistributionMockInstance.deployed()

    airdrop.initialize(drace.address, owner.address)
  })

  it('Claim normally', async function () {
    await airdrop.setClaimCount(1)
    await drace.transfer(airdrop.address, toWei('100000'))

    await airdrop.connect(claimer1).claimMock(toWei('100'), toWei('25'))
    await airdrop.connect(claimer2).claimMock(toWei('200'), toWei('50'))

    //cant claim
    await expect(airdrop.connect(claimer1).claimMock(toWei('100'), toWei('25'))).to.be.revertedWith('Your airdrop was burnt as you did not claim last time')
    await expect(airdrop.connect(claimer2).claimMock(toWei('200'), toWei('50'))).to.be.revertedWith('Your airdrop was burnt as you did not claim last time')

    //continue claim
    await airdrop.setClaimCount(2)
    await airdrop.connect(claimer1).claimMock(toWei('100'), toWei('25'))
    await airdrop.connect(claimer2).claimMock(toWei('200'), toWei('50'))
    })
})
