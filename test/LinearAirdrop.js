const { expect } = require('chai')
const { ethers } = require('hardhat')

function toWei(n) {
  return ethers.utils.parseEther(n)
}

describe('AirdropDistribution', async function () {
  const [owner, claimer1, claimer2, claimer3] = await ethers.getSigners()
  let drace, airdrop
  beforeEach(async () => {
    const DRACE = await ethers.getContractFactory('DRACE')
    const draceInstance = await DRACE.deploy(owner.address)
    drace = await draceInstance.deployed()

    const LinearAirdropMockMock = await ethers.getContractFactory(
      'LinearAirdropMock',
    )
    const LinearAirdropMockInstance = await LinearAirdropMockMock.deploy()
    airdrop = await LinearAirdropMockInstance.deployed()

    airdrop.initialize(drace.address, owner.address)
  })

  async function timeShift(n) {
    await ethers.provider.send('evm_increaseTime', [n])
  }

  it('Claim normally', async function () {
    await airdrop.setStartClaimTimestamp(0)
    await drace.transfer(airdrop.address, toWei('100000'))

    expect(await drace.balanceOf(claimer1.address)).to.be.eq(0)
    expect(await drace.balanceOf(claimer2.address)).to.be.eq(0)
    expect(await drace.balanceOf(claimer3.address)).to.be.eq(0)

    await airdrop.connect(claimer1).claimMock(toWei('100'))
    await airdrop.connect(claimer2).claimMock(toWei('200'))

    expect(await drace.balanceOf(claimer1.address)).to.not.eq(0)
    expect(await drace.balanceOf(claimer2.address)).to.not.eq(0)

    await timeShift(2 * 86400)

    await airdrop.connect(claimer1).claimMock(toWei('100'))
    await airdrop.connect(claimer2).claimMock(toWei('200'))

    await airdrop.connect(claimer1).claimAllClaimable()
    await airdrop.connect(claimer2).claimAllClaimable()

    await expect(
      airdrop.connect(claimer3).claimMock(toWei('100')),
    ).to.be.revertedWith(
      'Your airdrop was burnt due to not init vesting on time',
    )
    await expect(
      airdrop.connect(claimer3).claimAllClaimable(),
    ).to.be.revertedWith(
      'Your airdrop was burnt due to not init vesting on time',
    )
    await expect(airdrop.connect(claimer3).claimVesting(0)).to.be.reverted
    expect(await drace.balanceOf(claimer3.address)).to.be.eq(0)

    await airdrop.connect(claimer1).claimAllClaimable()
    await airdrop.connect(claimer2).claimAllClaimable()

    await timeShift(29 * 86400)
    await airdrop.connect(claimer1).claimAllClaimable()
    await airdrop.connect(claimer2).claimAllClaimable()

    expect(await drace.balanceOf(claimer1.address)).to.be.eq(toWei('25'))
    expect(await drace.balanceOf(claimer2.address)).to.be.eq(toWei('50'))
    
    let claim1Status = await airdrop.getUserStatus(claimer1.address)
    let claim2Status = await airdrop.getUserStatus(claimer2.address)
    let claim3Status = await airdrop.getUserStatus(claimer3.address)

    expect(claim1Status._claimable + claim1Status._lock).to.be.equal(toWei('75'))
    expect(claim2Status._claimable + claim2Status._lock).to.be.equal(toWei('150'))
    expect(claim3Status._claimable + claim3Status._lock).to.be.equal(toWei('0'))


    //cliff
    await timeShift(30 * 86400)
    
    await airdrop.connect(claimer1).claimAllClaimable()
    
    await timeShift(30 * 86400)
    await airdrop.connect(claimer1).claimAllClaimable()
    expect((await drace.balanceOf(claimer1.address)) - toWei('50') > 0).to.be.eq(true)

    await timeShift(2 * 86400)
    let balBefore = await drace.balanceOf(claimer2.address)
    await airdrop.connect(claimer2).claimVesting(1)
    let balAfter = await drace.balanceOf(claimer2.address)
    expect(balBefore).to.be.eq(balAfter)

    await timeShift(28 * 86400)
    await airdrop.connect(claimer1).claimAllClaimable()
    await airdrop.connect(claimer2).claimAllClaimable()

    claim1Status = await airdrop.getUserStatus(claimer1.address)
    claim2Status = await airdrop.getUserStatus(claimer2.address)
    claim3Status = await airdrop.getUserStatus(claimer3.address)

    await timeShift(30 * 86400)
    await airdrop.connect(claimer1).claimAllClaimable()
    await airdrop.connect(claimer2).claimAllClaimable()
    expect(await drace.balanceOf(claimer1.address)).to.be.eq(toWei('100'))
    expect(await drace.balanceOf(claimer2.address)).to.be.eq(toWei('150'))

    claim1Status = await airdrop.getUserStatus(claimer1.address)
    claim2Status = await airdrop.getUserStatus(claimer2.address)
    claim3Status = await airdrop.getUserStatus(claimer3.address)

    expect(claim1Status._claimable + claim1Status._lock).to.be.eq(toWei('0'))
    expect(claim2Status._claimable + claim2Status._lock).to.be.eq(toWei('0'))
    expect(claim3Status._claimable + claim3Status._lock).to.be.eq(toWei('0'))
  })
})
