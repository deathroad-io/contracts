const { expect } = require("chai");
const { ethers } = require("hardhat");
const signer = require('./signer')

describe("Marketplace", async function () {
    const [owner, upgrader] = await ethers.getSigners();
    var drace, deathRoadNFT, factory, featureNames, featureValues, featureNamesEncode, featureValuesSetEncode, ufeatureValues, ufeatureNamesEncode, ufeatureValuesSetEncode
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

        ufeatureValues = [["uf00", "uf01"], ["uf10", "uf11"], ["uf20", "uf21"]]
        ufeatureNamesEncode = [signer.encodeString(featureNames[0]), signer.encodeString(featureNames[1])]
        ufeatureValuesSetEncode = [
            [signer.encodeString(ufeatureValues[0][0]), signer.encodeString(ufeatureValues[0][1])],
            [signer.encodeString(ufeatureValues[1][0]), signer.encodeString(ufeatureValues[1][1])],
            [signer.encodeString(ufeatureValues[2][0]), signer.encodeString(ufeatureValues[2][1])]
        ]
    })

    it("Upgrade Failed with charm", async function () {
        let pair = signer.generateCommitment()
        await factory.mintCharm(upgrader.address)
        let expiryTime = 100000000000
        console.log(upgrader.address)
        let sig = signer.signCommitUpgrade(upgrader.address, tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode, 10000000000000, true, pair.commitment, expiryTime)

        //approve
        await deathRoadNFT.connect(upgrader).approve(factory.address, 1)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 2)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 3)

        await factory.connect(upgrader).commitUpgradeFeatures(
            tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode,
            10000000000000, true, pair.commitment, expiryTime,
            sig.r, sig.s, sig.v,
            { value: ethers.utils.parseEther('0.005') })

        //nft should be locked in the factory
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(factory.address)

        await factory.settleUpgradeFeatures(pair.secret)

        //should return ownership of nfts
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.currentId()).to.be.equal(3)
    });

    it("Upgrade Failed without charm", async function () {
        let pair = signer.generateCommitment()
        await factory.mintCharm(upgrader.address)
        let expiryTime = 100000000000
        console.log(upgrader.address)
        let sig = signer.signCommitUpgrade(upgrader.address, tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode, 10000000000000, false, pair.commitment, expiryTime)

        //approve
        await deathRoadNFT.connect(upgrader).approve(factory.address, 1)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 2)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 3)

        await factory.connect(upgrader).commitUpgradeFeatures(
            tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode,
            10000000000000, false, pair.commitment, expiryTime,
            sig.r, sig.s, sig.v,
            { value: ethers.utils.parseEther('0.005') })

        //nft should be locked in the factory
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(factory.address)

        await factory.settleUpgradeFeatures(pair.secret)

        //tokens should be burnt
        await expect(deathRoadNFT.ownerOf(1)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(2)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(3)).to.be.reverted
    });

    it("Upgrade Failed with charm, but then use charm for another update", async function () {
        await factory.mint(upgrader.address, featureNamesEncode, featureValuesSetEncode[0])
        await factory.mint(upgrader.address, featureNamesEncode, featureValuesSetEncode[1])
        await factory.mint(upgrader.address, featureNamesEncode, featureValuesSetEncode[2])

        let tokenIds2 = [4, 5, 6]
        let pair = signer.generateCommitment()
        let pair2 = signer.generateCommitment()

        await factory.mintCharm(upgrader.address)
        let expiryTime = 100000000000
        let sig = signer.signCommitUpgrade(upgrader.address, tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode, 10000000000000, true, pair.commitment, expiryTime)
        let sig2 = signer.signCommitUpgrade(upgrader.address, tokenIds2, ufeatureNamesEncode, ufeatureValuesSetEncode, 10000000000000, true, pair2.commitment, expiryTime)

        //approve
        await deathRoadNFT.connect(upgrader).approve(factory.address, 1)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 2)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 3)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 4)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 5)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 6)


        await factory.connect(upgrader).commitUpgradeFeatures(
            tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode,
            10000000000000, true, pair.commitment, expiryTime,
            sig.r, sig.s, sig.v,
            { value: ethers.utils.parseEther('0.005') })

        await factory.connect(upgrader).commitUpgradeFeatures(
            tokenIds2, ufeatureNamesEncode, ufeatureValuesSetEncode,
            10000000000000, true, pair2.commitment, expiryTime,
            sig2.r, sig2.s, sig2.v,
            { value: ethers.utils.parseEther('0.005') })

        //nft should be locked in the factory
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(4)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(5)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(6)).to.be.equal(factory.address)

        await factory.settleUpgradeFeatures(pair.secret)

        //should return ownership of nfts
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(upgrader.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(upgrader.address)

        await factory.settleUpgradeFeatures(pair2.secret)
        //tokens should be burnt
        await expect(deathRoadNFT.ownerOf(4)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(5)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(6)).to.be.reverted
    });

    it("Upgrade Success with charm", async function () {
        let pair = signer.generateCommitment()
        await factory.mintCharm(upgrader.address)
        let expiryTime = 100000000000
        console.log(upgrader.address)
        let sig = signer.signCommitUpgrade(upgrader.address, tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode, 0, true, pair.commitment, expiryTime)

        //approve
        await deathRoadNFT.connect(upgrader).approve(factory.address, 1)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 2)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 3)

        await factory.connect(upgrader).commitUpgradeFeatures(
            tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode,
            0, true, pair.commitment, expiryTime,
            sig.r, sig.s, sig.v,
            { value: ethers.utils.parseEther('0.005') })

        //nft should be locked in the factory
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(factory.address)

        await factory.settleUpgradeFeatures(pair.secret)

        //should return ownership of nfts
        //tokens should be burnt
        await expect(deathRoadNFT.ownerOf(1)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(2)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(3)).to.be.reverted
        expect(await deathRoadNFT.currentId()).to.be.equal(4)
        expect(await deathRoadNFT.ownerOf(4)).to.be.equal(upgrader.address)
    });

    it("Upgrade Success without charm", async function () {
        let pair = signer.generateCommitment()
        await factory.mintCharm(upgrader.address)
        let expiryTime = 100000000000
        console.log(upgrader.address)
        let sig = signer.signCommitUpgrade(upgrader.address, tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode, 0, false, pair.commitment, expiryTime)

        //approve
        await deathRoadNFT.connect(upgrader).approve(factory.address, 1)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 2)
        await deathRoadNFT.connect(upgrader).approve(factory.address, 3)

        await factory.connect(upgrader).commitUpgradeFeatures(
            tokenIds, ufeatureNamesEncode, ufeatureValuesSetEncode,
            0, false, pair.commitment, expiryTime,
            sig.r, sig.s, sig.v,
            { value: ethers.utils.parseEther('0.005') })

        //nft should be locked in the factory
        expect(await deathRoadNFT.ownerOf(1)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(2)).to.be.equal(factory.address)
        expect(await deathRoadNFT.ownerOf(3)).to.be.equal(factory.address)

        await factory.settleUpgradeFeatures(pair.secret)

        //should return ownership of nfts
        //tokens should be burnt
        await expect(deathRoadNFT.ownerOf(1)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(2)).to.be.reverted
        await expect(deathRoadNFT.ownerOf(3)).to.be.reverted
        expect(await deathRoadNFT.currentId()).to.be.equal(4)
        expect(await deathRoadNFT.ownerOf(4)).to.be.equal(upgrader.address)
    });
});