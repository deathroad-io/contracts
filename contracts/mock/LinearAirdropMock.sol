pragma solidity ^0.8.0;
import "../lib/LinearAirdrop.sol";

contract LinearAirdropMock is LinearAirdrop {
    function claimMock(uint256 _total) external {
        _claim(_total);
    }
}
