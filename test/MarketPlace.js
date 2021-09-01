const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Marketplace", function() {
  it("Marketplace", async function() {
    const [owner, seller, buyer] = await ethers.getSigners();

    const DRACE = await ethers.getContractFactory("DRACE");
    const draceInstance = await DRACE.deploy(owner.address);
    const drace = await draceInstance.deployed()

    const ownerBalance = await drace.balanceOf(owner.address);
    expect(await drace.totalSupply()).to.equal(ownerBalance);

    const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    const ERC721MockInstance = await ERC721Mock.deploy();
    const nft = await ERC721MockInstance.deployed()

    const FeeDistribution = await ethers.getContractFactory("FeeDistribution");
    const FeeDistributionInstance = await FeeDistribution.deploy();
    const distributor = await FeeDistributionInstance.deployed()

    const MarketPlace = await ethers.getContractFactory("MarketPlace");
    const MarketPlaceInstance = await MarketPlace.deploy();
    const mp = await MarketPlaceInstance.deployed()
    await mp.initialize(nft.address, drace.address, distributor.address)

    expect(await drace.balanceOf(distributor.address)).to.equal(0);

    await nft.mint(seller.address)
    await nft.mint(seller.address)

    expect(await nft.ownerOf(1)).to.equal(seller.address)
    expect(await nft.ownerOf(2)).to.equal(seller.address)

    await nft.connect(seller).approve(mp.address, 1)
    await nft.connect(seller).approve(mp.address, 2)

    await mp.connect(seller).setTokenSale(1, 10000000)
    await mp.connect(seller).setTokenSale(2, 20000000)
    expect(await mp.getSaleCount()).to.equal(2)
    let activeSales = await mp.getAllSales()

    expect(activeSales.length).to.equal(2)
    expect(activeSales[0].isSold).to.equal(false)
    expect(activeSales[0].isActive).to.equal(true)
    expect(activeSales[0].owner).to.equal(seller.address)
    expect(activeSales[0].tokenId).to.equal(1)
    expect(activeSales[0].price).to.equal(10000000)

    expect(activeSales[1].isSold).to.equal(false)
    expect(activeSales[1].isActive).to.equal(true)
    expect(activeSales[1].owner).to.equal(seller.address)
    expect(activeSales[1].tokenId).to.equal(2)
    expect(activeSales[1].price).to.equal(20000000)

    await mp.connect(seller).changeTokenSalePrice(0, 20000000)
    activeSales = await mp.getAllSales()
    expect(activeSales[0].isSold).to.equal(false)
    expect(activeSales[0].isActive).to.equal(true)
    expect(activeSales[0].owner).to.equal(seller.address)
    expect(activeSales[0].tokenId).to.equal(1)
    expect(activeSales[0].price).to.equal(20000000)

    await mp.connect(seller).changeTokenSalePrice(0, 10000000)

    await mp.connect(seller).cancelTokenSale(0)
    activeSales = await mp.getAllSales()
    expect(activeSales[0].isSold).to.equal(false)
    expect(activeSales[0].isActive).to.equal(false)
    expect(activeSales[0].owner).to.equal(seller.address)
    expect(activeSales[0].tokenId).to.equal(1)
    expect(activeSales[0].price).to.equal(10000000)
    expect(await nft.ownerOf(1)).to.equal(seller.address)

    await drace.transfer(buyer.address, 30000000)
    await drace.connect(buyer).approve(mp.address, 30000000)

    //cant buy inactive sale
    await expect(mp.buyToken(0)).to.be.reverted

    await nft.connect(seller).approve(mp.address, 1)
    await mp.connect(seller).setTokenSale(1, 10000000)

    await mp.connect(buyer).buyToken(1)
    await mp.connect(buyer).buyToken(2)

    expect(await nft.ownerOf(1)).to.equal(buyer.address)
    expect(await nft.ownerOf(2)).to.equal(buyer.address)
  });

  it("Distribution", async function() {
    const routerAddress = "0x10ED43C718714eb63d5aA57B78B54704E256024E"
    const [owner, foundation, playToEarn, liquidityReceiver] = await ethers.getSigners();

    const DRACE = await ethers.getContractFactory("DRACE");
    const draceInstance = await DRACE.deploy(owner.address);
    const drace = await draceInstance.deployed()

    const ownerBalance = await drace.balanceOf(owner.address);
    expect(await drace.totalSupply()).to.equal(ownerBalance);

    const FeeDistribution = await ethers.getContractFactory("FeeDistribution");
    const FeeDistributionInstance = await FeeDistribution.deploy();
    const distributor = await FeeDistributionInstance.deployed()
    await distributor.initialize(drace.address, [foundation.address, playToEarn.address, ethers.constants.AddressZero], [250, 250, 150])
    await distributor.setLiquidityReceiver(liquidityReceiver.address)
    await distributor.setRouter(routerAddress)

    //adding liquidity
    const router = await ethers.getContractAt("IPancakeRouter02", routerAddress)
    await drace.approve(routerAddress, ethers.constants.MaxUint256)

    await router.addLiquidityETH(drace.address, ethers.utils.parseEther('100'), 0, 0, owner.address, ethers.constants.MaxUint256, {value: ethers.utils.parseEther('100')})

    await drace.transfer(distributor.address, ethers.utils.parseEther('10'))
    await distributor.distribute()

  });
});