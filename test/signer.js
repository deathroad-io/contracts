const Web3 = require('web3')
const signer = "0xd1947a4bed78d2487417e165417c2555e6b31f506bba7c75f4b7c5633a8d425f"
const signerAddress = "0x4d62aa1580EBF2cc12BFFCf7Cb6651B0cde09e71"
module.exports = {
    signBuyBox: (buyer, boxType, packType, amount, expiryTime) => {
        let web3 = new Web3()
        let msg = web3.eth.abi.encodeParameters(
            ['string', 'address', 'bytes', 'bytes', 'uint256', 'uint256'],
            ['buyBox', buyer, boxType, packType, amount, expiryTime]
        )
        let msgHash = web3.utils.sha3(msg);
        let sig = web3.eth.accounts.sign(msgHash, signer);
        return { msgHash: msgHash, r: sig.r, s: sig.s, v: sig.v }
    },
    encodeString: (val) => {
        let web3 = new Web3()
        return web3.utils.asciiToHex(val)
    },
    signOpenBox: (owner, boxId, featureNames, featureValues, commitment, expiryTime) => {
        let web3 = new Web3()
        let msg = web3.eth.abi.encodeParameters(
            ['string', 'address', 'uint256', 'bytes[]', 'bytes[][]', 'bytes32', 'uint256'],
            ['commitOpenBox', owner, boxId, featureNames, featureValues, commitment, expiryTime]
        )
        let msgHash = web3.utils.sha3(msg);
        let sig = web3.eth.accounts.sign(msgHash, signer);
        return { msgHash: msgHash, r: sig.r, s: sig.s, v: sig.v }
    },
    signCommitUpgrade: (owner, _tokenIds, _featureNames, _featureValuesSet, _failureRate, _useCharm, commitment, expiryTime) => {
        console.log('_tokenIds', _tokenIds)
        let web3 = new Web3()
        let msg = web3.eth.abi.encodeParameters(
            ['string','address', 'uint256[3]', 'bytes[]', 'bytes[][]', 'uint256', 'bool', 'bytes32', 'uint256'],
            ['commitUpgradeFeatures', owner, _tokenIds, _featureNames, _featureValuesSet, _failureRate, _useCharm, commitment, expiryTime]
        )
        let msgHash = web3.utils.sha3(msg);
        let sig = web3.eth.accounts.sign(msgHash, signer);
        return { msg: msg, msgHash: msgHash, r: sig.r, s: sig.s, v: sig.v }
    },
    generateCommitment: () => {
        let web3 = new Web3()  
        let secret = web3.utils.randomHex(32)
        let msg = web3.eth.abi.encodeParameters(
            ['bytes32'],
            [secret]
        )
        let commitment = web3.utils.sha3(msg);
        return {secret, commitment}
    },
    signBuyCharm: (owner, amount, expiryTime) => {
        let web3 = new Web3()
        let msg = web3.eth.abi.encodeParameters(
            ['string', 'address', 'uint256', 'uint256'],
            ['buyCharm', owner, amount, expiryTime]
        )
        let msgHash = web3.utils.sha3(msg);
        let sig = web3.eth.accounts.sign(msgHash, signer);
        return { msgHash: msgHash, r: sig.r, s: sig.s, v: sig.v }
    },
    signClaim: (_txHash, _to, _amount, _sourceChainId, _targetChainId, _index) => {
        let web3 = new Web3()
        let msgHash = web3.utils.soliditySha3(
            { type: 'bytes32', value: _txHash },
            { type: 'address', value: _to },
            { type: 'uint256', value: _amount },
            { type: 'uint256', value: _sourceChainId },
            { type: 'uint256', value: _targetChainId },
            { type: 'uint256', value: _index }
        )
        let sig = web3.eth.accounts.sign(msgHash, signer);
        return { msgHash: msgHash, r: sig.r, s: sig.s, v: sig.v }
    },
    signerAddress
}

