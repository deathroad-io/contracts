const { expect } = require('chai')
const { ethers } = require('hardhat')

function toWei(n) {
  return ethers.utils.parseEther(n)
}

describe('TokenVesting', async function () {
  const [owner, claimer1, claimer2, claimer3] = await ethers.getSigners()
  let drace, tokenVesting
  beforeEach(async () => {
    const DRACE = await ethers.getContractFactory('DRACE')
    const draceInstance = await DRACE.deploy(owner.address)
    drace = await draceInstance.deployed()

    const TokenVesting = await ethers.getContractFactory(
      'TokenVesting',
    )
    const TokenVestingInstance = await TokenVesting.deploy()
    tokenVesting = await TokenVestingInstance.deployed()

    await tokenVesting.initialize(drace.address, 0)
    await tokenVesting.setLockers([owner.address], true)
  })

  async function timeShift(n) {
    await ethers.provider.send('evm_increaseTime', [n])
  }

  it('tokenVesting normally', async function () {
    await drace.approve(tokenVesting.address, toWei('1000000'))
    await expect(tokenVesting.connect(claimer1).lock(claimer1.address, 1)).to.be.revertedWith('only locker can lock')

    await tokenVesting.lock(claimer1.address, toWei('100'))
    await tokenVesting.lock(claimer2.address, toWei('100'))
    await tokenVesting.lock(claimer3.address, toWei('100'))

    await timeShift(10 * 86400)

    await tokenVesting.lock(claimer1.address, toWei('100'))
    await tokenVesting.lock(claimer2.address, toWei('100'))
    await tokenVesting.lock(claimer3.address, toWei('100'))

    expect(await tokenVesting.getUserVestingLength(claimer1.address)).to.be.equal(1)
    expect(await tokenVesting.getUserVestingLength(claimer2.address)).to.be.equal(1)
    expect(await tokenVesting.getUserVestingLength(claimer3.address)).to.be.equal(1)

    

    await timeShift(10 * 86400)

    await tokenVesting.lock(claimer1.address, toWei('100'))
    await tokenVesting.lock(claimer2.address, toWei('100'))
    await tokenVesting.lock(claimer3.address, toWei('100'))

    await tokenVesting.unlock(claimer1.address, [0, 1])
    await tokenVesting.unlock(claimer2.address, [0, 1])
    await tokenVesting.unlock(claimer3.address, [0, 1])

    expect(await drace.balanceOf(claimer1.address)).to.be.equal(0)
    expect(await drace.balanceOf(claimer2.address)).to.be.equal(0)
    expect(await drace.balanceOf(claimer3.address)).to.be.equal(0)

    await timeShift(20 * 86400)

    await tokenVesting.lock(claimer1.address, toWei('100'))
    await tokenVesting.lock(claimer2.address, toWei('100'))
    await tokenVesting.lock(claimer3.address, toWei('100'))

    await tokenVesting.lock(claimer1.address, toWei('100'))
    await tokenVesting.lock(claimer2.address, toWei('100'))
    await tokenVesting.lock(claimer3.address, toWei('100'))

    await timeShift(35 * 86400)

    await tokenVesting.lock(claimer1.address, toWei('100'))
    await tokenVesting.lock(claimer2.address, toWei('100'))
    await tokenVesting.lock(claimer3.address, toWei('100'))

    await tokenVesting.unlock(claimer1.address, [0, 1])
    await tokenVesting.unlock(claimer2.address, [0, 1])
    await tokenVesting.unlock(claimer3.address, [0, 1])
    expect(await drace.balanceOf(claimer1.address)).to.not.equal(0)
    expect(await drace.balanceOf(claimer2.address)).to.not.equal(0)
    expect(await drace.balanceOf(claimer3.address)).to.not.equal(0)

    await timeShift(800 * 86400)

    let vestingLength = await tokenVesting.getUserVestingLength(claimer1.address)
    let arr = []
    for(var i = 0; i < vestingLength; i++) {
        arr.push(i)
    }

    await tokenVesting.unlock(claimer1.address, arr)
    await tokenVesting.unlock(claimer2.address, arr)
    await tokenVesting.unlock(claimer3.address, arr)
    expect(await drace.balanceOf(claimer1.address)).to.be.equal(toWei('600'))
    expect(await drace.balanceOf(claimer2.address)).to.be.equal(toWei('600'))
    expect(await drace.balanceOf(claimer3.address)).to.be.equal(toWei('600'))

    await tokenVesting.unlock(claimer1.address, arr)
    await tokenVesting.unlock(claimer2.address, arr)
    await tokenVesting.unlock(claimer3.address, arr)

    expect(await drace.balanceOf(claimer1.address)).to.be.equal(toWei('600'))
    expect(await drace.balanceOf(claimer2.address)).to.be.equal(toWei('600'))
    expect(await drace.balanceOf(claimer3.address)).to.be.equal(toWei('600'))

  })
})
