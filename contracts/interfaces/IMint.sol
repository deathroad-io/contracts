pragma solidity ^0.8.0;

interface IMint {
    function mint(address _to, uint256 _amount) external;
}
