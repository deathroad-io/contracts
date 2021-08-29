pragma solidity ^0.8.0;
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IDeathRoadNFT.sol";

contract NotaryNFT is INotaryNFT {
    function getUpgradeResult(bytes32 secret, address nftFactory) external override view returns (bool) {
        IDeathRoadNFT factory = IDeathRoadNFT(nftFactory);
        bytes32 commitment = keccak256(abi.encode(secret));
        IDeathRoadNFT.UpgradeInfo memory info = factory.upgradesInfo(commitment);

        uint256[3] memory tokenIDs = info.tokenIds;

        
        //TODO: implement notary
        return true;
    }
}