pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FarmingRewardContainer is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public drace;
    address public masterChef;
    constructor(address _drace) public {
        drace = IERC20(_drace);
    }

    function setMasterchef(address _masterChef) external onlyOwner {
        masterChef = _masterChef;
    }

    function getRewards(address _recipient, uint256 _amount) external returns (uint256) {
        require(masterChef == msg.sender, "!masterchef");
        uint256 ret = _amount;
        uint256 bal = drace.balanceOf(address(this));
        if (ret > bal) {
            ret = bal;
        }
        drace.safeTransfer(_recipient, ret);
        return ret;
    }
}