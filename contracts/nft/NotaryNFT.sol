pragma solidity ^0.8.0;
import "../interfaces/INotaryNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/INFTFactoryV2.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NotaryNFT is INotaryNFT {
    using SafeMath for uint256;

    function getUpgradeResult(bytes32 secret, address nftFactory)
        external
        view
        override
        returns (bool, uint256)
    {
        INFTFactoryV2 factory = INFTFactoryV2(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactoryV2.UpgradeInfoV2 memory info = factory.upgradesInfoV2(commitment);

        bytes32 hash = keccak256(
            abi.encode(
                info.user,
                info.useCharm,
                info.failureRate,
                info.tokenIds,
                info.featureValueIndexesSet,
                info.previousBlockHash,
                secret
            )
        );
        uint256 h = uint256(hash);
        uint256 sum = info.featureValueIndexesSet.length.add(info.failureRate);
        uint256 ret = h.mod(sum);
        
        return (ret < info.featureValueIndexesSet.length, ret < info.featureValueIndexesSet.length ? info.featureValueIndexesSet[ret]:ret);
    }

    function getOpenBoxResult(bytes32 secret, address nftFactory)
        external
        view
        override
        returns (uint256[] memory)
    {
        INFTFactory factory = INFTFactory(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactory.OpenBoxInfo memory info = factory.openBoxInfo(commitment);

        uint256[] memory randomResult = new uint256[](info.boxCount);
        uint256 boxCount = info.boxCount;
        bytes32 initialHash = keccak256(
            abi.encode(
                info.user,
                info.boxIdFrom,
                info.featureValuesSet,
                info.previousBlockHash,
                secret
            )
        );
        bytes32 previousHash = info.previousBlockHash;

        for (uint256 i = 0; i < boxCount; i++) {
            bytes32 hash = previousHash & initialHash;
            uint256 h = uint256(hash);
            uint256 x = h.mod(info.featureValuesSet.length);
            randomResult[i] = info.featureValuesSet[x];
            previousHash = keccak256(abi.encode(previousHash, i));
        }

        return randomResult;
    }
}
