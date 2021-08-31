const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Bridge", function() {
  it("Deployment should assign the total supply of tokens to the owner", async function() {
    const [owner, seller, buyer, feeReceiver] = await ethers.getSigners();

    const DRACE = await ethers.getContractFactory("DRACE");
    const draceInstance = await DRACE.deploy(owner.address);
    const drace = await draceInstance.deployed()

    const ownerBalance = await drace.balanceOf(owner.address);
    expect(await drace.totalSupply()).to.equal(ownerBalance);

    const ERC721Mock = await ethers.getContractFactory("ERC721Mock");
    const ERC721MockInstance = await ERC721Mock.deploy();
    const nft = await ERC721MockInstance.deployed()

    const MarketPlace = await ethers.getContractFactory("MarketPlace");
    const MarketPlaceInstance = await MarketPlace.deploy();
    const mp = await MarketPlaceInstance.deployed()
    await mp.initialize(nft.address, drace.address, feeReceiver.address)

    expect(await drace.balanceOf(feeReceiver.address)).to.equal(0);

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
});