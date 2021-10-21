pragma solidity ^0.8.0;

interface IxDraceDistributor {
    struct VestingInfo {
        uint256 unlockedFrom;
        uint256 unlockedTo;
        uint256 releasedAmount;
        uint256 totalAmount;
    }
    function lock(address _addr, uint256 _amount) external;
    function getLockedInfo(address _addr) external view returns (uint256 _locked, uint256 _releasable);
    function unlock(address _addr) external;
    function vestings(address _addr) external view returns (VestingInfo memory);
}