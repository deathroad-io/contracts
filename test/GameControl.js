const { expect } = require("chai");
const { ethers } = require("hardhat");
const signer = require('./signer')
const deployUtil = require('./deployUtil')

describe("Game Control", async function () {
    const [owner, player] = await ethers.getSigners();
    var drace, deathRoadNFT, factory, featureNames, featureValues, featureNamesEncode, featureValuesSetEncode, ufeatureValues, ufeatureNamesEncode, ufeatureValuesSetEncode
    let tokenIds
    beforeEach(async () => {
        [drace, deathRoadNFT, factory, featureNames, featureValues, featureNamesEncode, featureValuesSetEncode, ufeatureValues, ufeatureNamesEncode, ufeatureValuesSetEncode, tokenIds] = await deployUtil.deploy(player)
    })

    it("Upgrade Failed with charm", async function () {

    });
});