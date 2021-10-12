pragma solidity ^0.8.0;
interface IReferralContract {
    function getReferrer(address _player) external view returns (address referrer, bool canReceive);
}