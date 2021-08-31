pragma solidity ^0.8.0;
import "../interfaces/INFTFactory.sol";
import "../interfaces/INFTUsePeriod.sol";

contract NFTUsePeriod is INFTUsePeriod {
    function getNFTUsePeriod(uint256 _tokenId, address _nftFactory) external override view returns (uint256) {
        INFTFactory factory = INFTFactory(_nftFactory);

        //TODO: implement period based on token id
        return 3600*2;
    } 
}