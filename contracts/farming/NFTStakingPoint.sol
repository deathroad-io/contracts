pragma solidity ^0.8.0;
import "../interfaces/INFTStakingPoint.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTStakingPoint is Ownable {
    mapping(uint256 => mapping (address => uint256)) public specialTokenPoint;
    mapping(bytes => uint256) public tokenPackPoint;
    uint256 public constant MAX_UINT = type(uint).max;
    // function getStakingPoint(uint256 _tokenId, address _nftContract)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     if (specialTokenPoint[_tokenId][_tokenId] != 0) {
    //         return specialTokenPoint[_tokenId][_tokenId];
    //     }
    //     IDeathRoadNFT nft = IDeathRoadNFT(_nftContract);
    //     if (!nft.existTokenFeatures(_tokenId)) return 0;
    //     //get features
    //     (bytes[] memory _featureNames, bytes[] memory _featureValues) = nft.getTokenFeatures(_tokenId);

    //     uint256 packIndex = MAX_UINT;
    //     uint256 typeIndex = MAX_UINT;
    //     // for(uint256 i = 0; i < _featureNames.length; i++) {
    //     //     if (packIndex != MAX_UINT && typeIndex != MAX_UINT) break;


    //     // }

    //     return 500e18;
    // }

    // function setTokenStakingPoint(uint256 _tokenId, address _tokenAddress, uint256 point) external onlyOwner {
    //     specialTokenPoint[_tokenId][_tokenAddress] = point;
    // }

    // function setTokenPackPoint(bytes memory _pack, uint256 _point) external onlyOwner {
    //     tokenPackPoint[_pack] = _point;
    // }
}
