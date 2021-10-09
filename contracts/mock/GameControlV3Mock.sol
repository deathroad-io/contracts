pragma solidity ^0.8.0;

import "../game/GameControlV3.sol";

contract GameControlV3Mock is GameControlV3 {

    function depositNFTsToPlayMock(
        uint256[] memory _tokenIds,
        uint64[] memory _freeTurns
    ) external {
        _depositNFTsToPlay(_tokenIds, _freeTurns);
    }

    function withdrawTokensMock(
        uint256 _pendingToSpendDrace,
        uint256 _pendingToSpendxDrace,
        bytes32 _withdrawId
    ) external {
        _withdrawTokens(_pendingToSpendDrace, _pendingToSpendxDrace, _withdrawId);
    }

    function withdrawAllNFTsMock(
        uint64[] memory _spentPlayTurns,
        bytes32 _withdrawId
    ) external {
        _withdrawAllNFTs(_spentPlayTurns, _withdrawId);
    }

    function withdrawNFTMock(
        uint256 _tokenId,
        uint64 _spentPlayTurn,
        bytes32 _withdrawId
    ) external {
        _withdrawNFT(_tokenId, _spentPlayTurn, _withdrawId);
    }

    function distributeRewardMock(
        uint256 _draceAmount,
        uint256 _xDraceAmount,
        bytes32 _withdrawId
    ) external {
        _distribute(
            msg.sender,
            _draceAmount,
            _xDraceAmount,
            _withdrawId
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
