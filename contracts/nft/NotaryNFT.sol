pragma solidity ^0.8.0;
import "../interfaces/INotaryNFT.sol";
import "../interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NotaryNFT is INotaryNFT {
    using SafeMath for uint256;
    function getUpgradeResult(bytes32 secret, address nftFactory) external override view returns (bool, uint256) {
        INFTFactory factory = INFTFactory(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactory.UpgradeInfo memory info = factory.upgradesInfo(commitment);

        bytes32 hash = keccak256(abi.encode(info.user, info.useCharm, info.failureRate, info.tokenIds, info.targetFeatureNames, info.targetFeatureValuesSet, info.previousBlockHash, secret));
        uint256 h = uint256(hash);
        uint256 sum = info.targetFeatureValuesSet.length.add(info.failureRate);
        uint256 ret = h.mod(sum);
        return (ret < info.targetFeatureValuesSet.length, ret);
    }

    function getOpenBoxResult(bytes32 secret, address nftFactory) external override view returns (uint256[] memory) {
        INFTFactory factory = INFTFactory(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactory.OpenBoxInfo memory info = factory.openBoxInfo(commitment);

        uint256[] memory randomResult = new uint256[](info.boxCount);
        bytes32 hash = keccak256(abi.encode(info.user, info.boxId, info.featureNames, info.featureValuesSet, info.previousBlockHash, secret));
        uint256 h = uint256(hash);
        uint256 randomResult = h.mod(info.featureValuesSet.length);

        return randomResult;
    }
}