pragma solidity ^0.8.0;
import "../interfaces/INFTFactory.sol";
import "../interfaces/INFTCountdown.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTCountdown is INFTCountdown, Ownable  {
    uint256 public defaultCountdown;
    function getCountdownPeriod(uint256 _tokenId, address _nftFactory) external override view returns (uint256) {
        INFTFactory factory = INFTFactory(_nftFactory);

        //TODO: implement period based on token id
        return defaultCountdown;
    } 

    function setDefaultCountDown(uint256 _x) external onlyOwner {
        defaultCountdown = _x;
    }
}