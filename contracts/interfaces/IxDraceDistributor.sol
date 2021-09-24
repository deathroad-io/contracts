pragma solidity ^0.8.0;

interface IxDraceDistributor {
    function lock(address _addr, uint256 _amount) external;
    function getLockedInfo(address _addr) external view returns (uint256 _locked, uint256 _releasable);
}