const { expect } = require("chai");
const { ethers } = require("hardhat");
const signer = require('./signer')

describe("GameControl", async function () {
    const [owner, upgrader] = await ethers.getSigners();
    var drace, deathRoadNFT, factory, featureNames, featureValues, featureNamesEncode, featureValuesSetEncode
    let tokenIds
    beforeEach(async () => {
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

        await factory.initialize(deathRoadNFT.address, drace.address, owner.address, notaryNFT.address)

        //mint 3 tokens to upgrader
        featureNames = ["f0", "f1"]
        featureValues = [["f00", "f01"], ["f10", "f11"], ["f20", "f21"]]
        featureNamesEncode = [signer.encodeString(featureNames[0]), signer.encodeString(featureNames[1])]
        featureValuesSetEncode = [
            [signer.encodeString(featureValues[0][0]), signer.encodeString(featureValues[0][1])],
            [signer.encodeString(featureValues[1][0]), signer.encodeString(featureValues[1][1])],
            [signer.encodeString(featureValues[2][0]), signer.encodeString(featureValues[2][1])]
        ]

        await factory.mint(upgrader.address, featureNamesEncode, featureValuesSetEncode[0])
        await factory.mint(upgrader.address, featureNamesEncode, featureValuesSetEncode[1])
        await factory.mint(upgrader.address, featureNamesEncode, featureValuesSetEncode[2])

        tokenIds = [1, 2, 3]

        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(upgrader.address)
    })

    it("Upgrade Failed with charm", async function () {

    });
});