pragma solidity ^0.8.0;
import "../interfaces/INFTStakingPoint.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTStakingPoint is Ownable, INFTStakingPoint {
    mapping(uint256 => uint256) public specialTokenPoint;
    //pack=>type=>point
    mapping(bytes => mapping(bytes => uint256)) public tokenPackPoint;
    uint256 public constant MAX_UINT = type(uint).max;

    bytes public packAscii = hex"7061636b";
    bytes public typeAscii = hex"74797065";

    constructor() {
        //1star => car => 100
        tokenPackPoint[hex"3173746172"][hex"636172"] = 100e18;
        //2star => car => 250
        tokenPackPoint[hex"3273746172"][hex"636172"] = 300e18;
        //3star => car => 600
        tokenPackPoint[hex"3373746172"][hex"636172"] = 900e18;

        //gun
        //1star => car => 100
        tokenPackPoint[hex"3173746172"][hex"67756e"] = 100e18;
        //2star => car => 250
        tokenPackPoint[hex"3273746172"][hex"67756e"] = 300e18;
        //3star => car => 600
        tokenPackPoint[hex"3373746172"][hex"67756e"] = 900e18;

        //gun
        //1star => car => 100
        tokenPackPoint[hex"3173746172"][hex"726f636b6574"] = 100e18;
        //2star => car => 250
        tokenPackPoint[hex"3273746172"][hex"726f636b6574"] = 300e18;
        //3star => car => 600
        tokenPackPoint[hex"3373746172"][hex"726f636b6574"] = 900e18;
    }
    function getStakingPoint(uint256 _tokenId, address _nftContract)
        external
        override
        view
        returns (uint256)
    {
        if (specialTokenPoint[_tokenId] != 0) {
            return specialTokenPoint[_tokenId];
        }
        IDeathRoadNFT nft = IDeathRoadNFT(_nftContract);
        if (!nft.existTokenFeatures(_tokenId)) return 0;
        //get features
        (bytes[] memory _featureNames, bytes[] memory _featureValues) = nft.getTokenFeatures(_tokenId);

        uint256 packIndex = MAX_UINT;
        uint256 typeIndex = MAX_UINT;
        for(uint256 i = 0; i < _featureNames.length; i++) {
            if (packIndex == MAX_UINT) {
                if (keccak256(_featureNames[i]) == keccak256(packAscii)) {
                    packIndex = i;
                }
            }

            if (typeIndex == MAX_UINT) {
                if (keccak256(_featureNames[i]) == keccak256(typeAscii)) {
                    typeIndex = i;
                }
            }
            if (packIndex != MAX_UINT && typeIndex != MAX_UINT) break;
        }

        if (packIndex == MAX_UINT && typeIndex == MAX_UINT) {
            //dont find pack and type in feature names
            return 0;
        }

        return tokenPackPoint[_featureValues[packIndex]][_featureValues[typeIndex]];
    }

    function setSpecialTokenStakingPoint(uint256 _tokenId, uint256 point) external onlyOwner {
        specialTokenPoint[_tokenId] = point;
    }

    function getSpecialTokenStakingPoint(uint256 _tokenId) external view returns (uint256) {
        return specialTokenPoint[_tokenId];
    }

    function setTokenPackPoint(bytes memory _pack, bytes memory _type, uint256 _point) external onlyOwner {
        tokenPackPoint[_pack][_type] = _point;
    }
}
