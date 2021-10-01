pragma solidity ^0.8.0;
interface INFTCountdown {
    function getCountdownPeriod(uint256 _tokenId, address _nftFactory) external view returns (uint256);

    function getFreePlayingTurn(uint256 _tokenId) external view returns (uint256);
}