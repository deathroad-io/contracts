pragma solidity ^0.8.0;
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NotaryNFT is INotaryNFT {
    using SafeMath for uint256;
    function getUpgradeResult(bytes32 secret, address nftFactory) external override view returns (bool) {
        IDeathRoadNFT factory = IDeathRoadNFT(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        IDeathRoadNFT.UpgradeInfo memory info = factory.upgradesInfo(commitment);

        bytes32 hash = keccak256(abi.encode(info.user, info.useCharm, info.successRate, info.tokenIds, info.targetFeatureNames, info.targetFeatureValues, info.previousBlockHash, secret));
        uint256 h = uint256(hash);
        return h.mod(1000) < info.successRate;
    }
}