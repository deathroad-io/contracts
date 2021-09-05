pragma solidity ^0.8.0;

import "../game/GameControl.sol";

contract GameControlMock is GameControl {
    function startGameMock(uint256[] memory _tokenIds) external {
        _startGame(_tokenIds);
    }

    function distributeRewardMock(
        address _recipient,
        uint256 _rewardAmount,
        uint256 _cumulativeReward,
        uint256 _gameId
    ) external {
        _distribute(_recipient, _rewardAmount, _cumulativeReward, _gameId);
    }
}
