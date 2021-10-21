pragma solidity ^0.8.0;

import "../interfaces/IxDraceDistributor.sol";
import "../interfaces/IMint.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract UnlockHelper is Ownable {
    IxDraceDistributor public xDraceVesting = IxDraceDistributor(0x8f1535AEf2502E63FB76d1D15Bc3Eb4c522b730b);
    IMint private xDrace = IMint(0x2F7694695d71CAaaE29FDF3F140530d057de970B);
    mapping(address => bool) public fullUnlocked;
    function getLockedInfo(address _addr) public view returns (uint256 _locked, uint256 _releasable) {
        return xDraceVesting.getLockedInfo(_addr);
    }

    function unlock(address _addr) external {
        require(!fullUnlocked[_addr], "already unlocked");

        xDraceVesting.unlock(_addr);   

        IxDraceDistributor.VestingInfo memory vestingInfo = xDraceVesting.vestings(_addr);

        if ((vestingInfo.unlockedFrom + 14 days) < block.timestamp) {
            uint256 amount = 0;
            if (vestingInfo.totalAmount >= vestingInfo.releasedAmount) {
                amount = vestingInfo.totalAmount - vestingInfo.releasedAmount;
            }
            fullUnlocked[_addr] = true;
            xDrace.mint(_addr, amount);
        } else {
            //do nothing
        }
    }
}