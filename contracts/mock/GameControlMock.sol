pragma solidity ^0.8.0;

import "../game/GameControl.sol";

contract GameControlMock is GameControl {
    function startGameMock(uint256[] memory _tokenIds) external {
        _startGame(_tokenIds);
    }

    function distributeRewardMock(
        uint256 _draceAmount,
        uint256 _xDraceAmount,
        uint256 _cumulativeReward,
        uint256[] memory _gameIds,
        bool _withdrawNFT
    ) external {
        _distribute(
            msg.sender,
            _draceAmount,
            _xDraceAmount,
            _cumulativeReward,
            _gameIds,
            _withdrawNFT
        );
    }

    function buyPlayingTurnMock(
        uint256 _tokenId,
        uint256 _price, //price per turn
        uint256 _turnCount,
        bool _usexDrace
    ) external {
        _buyPlayingTurn(_tokenId, _price, _turnCount, _usexDrace);
    }
}
