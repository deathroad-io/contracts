pragma solidity ^0.8.0;

interface INotaryNFT {
    function getUpgradeResult(bytes32 secret, address nftFactory) external view returns (bool);
    function getOpenBoxResult(bytes32 secret, uint256 _resultIndex, address nftFactory) external view returns (bool);
}