const { expect } = require("chai");
const { ethers } = require("hardhat");
const signer = require('./signer')

async function deploy(initialTokenReceiver) {
    const [owner] = await ethers.getSigners();
    var drace, deathRoadNFT, factory, featureNames, featureValues, featureNamesEncode, featureValuesSetEncode, ufeatureValues, ufeatureNamesEncode, ufeatureValuesSetEncode
    let tokenIds
    const DRACE = await ethers.getContractFactory("DRACE");
    const draceInstance = await DRACE.deploy(owner.address);
    drace = await draceInstance.deployed()

    const DeathRoadNFT = await ethers.getContractFactory('DeathRoadNFT');
    const deathRoadNFTInstance = await DeathRoadNFT.deploy()
    deathRoadNFT = await deathRoadNFTInstance.deployed()

    const NFTFactoryMock = await ethers.getContractFactory('NFTFactoryMock')
    const NFTFactoryMockInstance = await NFTFactoryMock.deploy()
    factory = await NFTFactoryMockInstance.deployed()

    await deathRoadNFT.initialize(factory.address)

    const NotaryNFT = await ethers.getContractFactory('NotaryNFT');
    const notaryNFTInstance = await NotaryNFT.deploy()
    const notaryNFT = await notaryNFTInstance.deployed()

    await factory.addApprover(signer.signerAddress, true);
    await factory.setSettleFeeReceiver(owner.address)
    expect(await factory.mappingApprover(signer.signerAddress)).to.be.equal(true)

    await factory.initialize(deathRoadNFT.address, drace.address, owner.address, notaryNFT.address, ethers.constants.AddressZero)

    //mint 3 tokens to initialTokenReceiver
    featureNames = ["f0", "f1"]
    featureValues = [["f00", "f01"], ["f10", "f11"], ["f20", "f21"]]
    featureNamesEncode = [signer.encodeString(featureNames[0]), signer.encodeString(featureNames[1])]
    featureValuesSetEncode = [
        [signer.encodeString(featureValues[0][0]), signer.encodeString(featureValues[0][1])],
        [signer.encodeString(featureValues[1][0]), signer.encodeString(featureValues[1][1])],
        [signer.encodeString(featureValues[2][0]), signer.encodeString(featureValues[2][1])]
    ]

    await factory.mint(initialTokenReceiver.address, featureNamesEncode, featureValuesSetEncode[0])
    await factory.mint(initialTokenReceiver.address, featureNamesEncode, featureValuesSetEncode[1])
    await factory.mint(initialTokenReceiver.address, featureNamesEncode, featureValuesSetEncode[2])

    tokenIds = [1, 2, 3]

    expect(await deathRoadNFT.ownerOf(1)).to.be.equal(initialTokenReceiver.address)
    expect(await deathRoadNFT.ownerOf(2)).to.be.equal(initialTokenReceiver.address)
    expect(await deathRoadNFT.ownerOf(3)).to.be.equal(initialTokenReceiver.address)

    ufeatureValues = [["uf00", "uf01"], ["uf10", "uf11"], ["uf20", "uf21"]]
    ufeatureNamesEncode = [signer.encodeString(featureNames[0]), signer.encodeString(featureNames[1])]
    ufeatureValuesSetEncode = [
        [signer.encodeString(ufeatureValues[0][0]), signer.encodeString(ufeatureValues[0][1])],
        [signer.encodeString(ufeatureValues[1][0]), signer.encodeString(ufeatureValues[1][1])],
        [signer.encodeString(ufeatureValues[2][0]), signer.encodeString(ufeatureValues[2][1])]
    ]

    return [drace, deathRoadNFT, factory, featureNames, featureValues, featureNamesEncode, featureValuesSetEncode, ufeatureValues, ufeatureNamesEncode, ufeatureValuesSetEncode, tokenIds]
}

module.exports = {
    deploy
}