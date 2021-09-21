pragma solidity ^0.8.0;
import "../lib/AirdropDistribution.sol";

contract AirdropDistributionMock is AirdropDistribution {
    function claimMock(uint256 _total, uint256 _toClaim) external {
        _claim(_total, _toClaim);
    }
}
