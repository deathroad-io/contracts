pragma solidity ^0.8.0;
import "../interfaces/INotaryNFT.sol";
import "../interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NotaryNFT is INotaryNFT {
    using SafeMath for uint256;
    function getUpgradeResult(bytes32 secret, address nftFactory) external override view returns (bool) {
        INFTFactory factory = INFTFactory(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactory.UpgradeInfo memory info = factory.upgradesInfo(commitment);

        bytes32 hash = keccak256(abi.encode(info.user, info.useCharm, info.successRate, info.tokenIds, info.targetFeatureNames, info.targetFeatureValues, info.previousBlockHash, secret));
        uint256 h = uint256(hash);
        return h.mod(1000) < info.successRate;
    }

    function getOpenBoxResult(bytes32 secret, uint256 _resultIndex, address nftFactory) external override view returns (bool) {
        INFTFactory factory = INFTFactory(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactory.OpenBoxBasicInfo memory info = factory.getBasicOpenBoxInfo(commitment);

        bytes32 hash = keccak256(abi.encode(info.user, info.boxId, info.featureNames, info.featureValuesSet, info.previousBlockHash, secret));
        uint256 h = uint256(hash);
        uint256 randomResult = h.mod(info.totalRate);

        uint256[2] memory successRateRange = factory.getSuccessRateRange(commitment, _resultIndex);
        return successRateRange[0] <= randomResult && randomResult < successRateRange[1];
    }
}