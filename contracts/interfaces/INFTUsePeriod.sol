pragma solidity ^0.8.0;
interface INFTUsePeriod {
    function getNFTUsePeriod(uint256 _tokenId, address _nftFactory) external view returns (uint256);
}