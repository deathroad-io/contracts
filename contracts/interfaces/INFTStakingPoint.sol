pragma solidity ^0.8.0;

interface INFTStakingPoint {
    function getStakingPoint(uint256 _tokenId, address _nftContract) external view returns (uint256);
}