pragma solidity ^0.8.0;

interface ITokenVesting {
    function lock(address _addr, uint256 _amount) external;
}