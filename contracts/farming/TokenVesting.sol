pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract TokenVesting is Initializable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct VestingInfo {
        uint256 lockedTil;
        uint256 releasedAmount;
        uint256 totalAmount;
    }
    uint256 public vestingPeriod;
    IERC20 public token;
    mapping(address => VestingInfo) public vestings;

    function initialize(address _token, uint256 _vestingPeriod)
        external
        initializer
    {
        token = IERC20(_token);
        vestingPeriod = _vestingPeriod;
    }

    function unlock(address _addr) public {
        uint256 unlockable = getUnlockable(_addr);
        if (unlockable > 0) {
            //release it
            VestingInfo storage vesting = vestings[_addr];
            vesting.releasedAmount = vesting.releasedAmount.sub(unlockable);
            token.safeTransfer(_addr, unlockable);
        }
    }

    function lock(address _addr, uint256 _amount) external {
        unlock(_addr);
        if (_amount > 0) {
            token.safeTransferFrom(msg.sender, address(this), _amount);

            VestingInfo storage vesting = vestings[_addr];
            vesting.lockedTil = block.timestamp.add(vestingPeriod);
            vesting.totalAmount = vesting.totalAmount.add(_amount);
        }
    }

    function getUnlockable(address _addr) public view returns (uint256) {
        VestingInfo storage vesting = vestings[_addr];
        if (vesting.totalAmount > 0) {
            return 0;
        }

        uint256 lockedAt = vesting.lockedTil.sub(vestingPeriod);
        uint256 timeElapsed = block.timestamp.sub(lockedAt);

        uint256 releasable = timeElapsed.mul(vesting.totalAmount).div(
            vestingPeriod
        );
        if (releasable > vesting.totalAmount) {
            releasable = vesting.totalAmount;
        }
        return releasable.sub(vesting.releasedAmount);
    }
}
