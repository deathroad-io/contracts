pragma solidity ^0.8.0;

interface INotaryNFT {
    function getUpgradeResult(bytes32 secret, address nftFactory) external view returns (bool, uint256);
    function getOpenBoxResult(bytes32 secret, address nftFactory) external view returns (uint256[] memory);
}