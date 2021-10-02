pragma solidity ^0.8.0;
import "../interfaces/INFTFactory.sol";
import "../interfaces/INFTCountdown.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTCountdown is INFTCountdown, Ownable  {
    uint256 public defaultCountdown;
    mapping(uint64 => uint256) public freePlayTurns;
    mapping(uint64 => uint256) public countdowns;
    function getCountdownPeriod(uint256 _tokenId, address _nftFactory) external override view returns (uint256) {
        return countdowns[uint64(_tokenId)];
    } 

    function setDefaultCountdown(uint256 _x) external onlyOwner {
        defaultCountdown = _x;
    }

    function getFreePlayingTurn(uint256 _tokenId) external view override returns (uint256) {
        //return freePlayTurns[uint64(_tokenId)];
        return type(uint256).max;
    }

    function setFreePlayingTurns(uint64[] calldata _tokenIds, uint256 turnCount) external onlyOwner {
        uint256 len = _tokenIds.length;
        for(uint256 i = 0; i < len; i++) {
            freePlayTurns[_tokenIds[i]] = turnCount;
        }
    }

    function setCountdown(uint64[] calldata _tokenIds, uint256 countdown) external onlyOwner {
        uint256 len = _tokenIds.length;
        for(uint256 i = 0; i < len; i++) {
            countdowns[_tokenIds[i]] = countdown;
        }
    }

    function setFreePlayingTurnsAndCountdowns(uint64[] calldata _tokenIds, uint256 turnCount, uint256 countdown) external onlyOwner {
        uint256 len = _tokenIds.length;
        for(uint256 i = 0; i < len; i++) {
            freePlayTurns[_tokenIds[i]] = turnCount;
            countdowns[_tokenIds[i]] = countdown;
        }
    }
}