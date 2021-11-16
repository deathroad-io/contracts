pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IxDraceDistributor.sol";

contract xDraceRewardLocker is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct VestingInfo {
        uint256 unlockedFrom;
        uint256 unlockedTo;
        uint256 releasedAmount;
        uint256 totalAmount;
    }
    uint256 public vestingPeriod;
    IERC20Upgradeable public token;
    mapping(address => VestingInfo) public vestings;
    mapping(address => bool) public lockers;

    event Lock(address user, uint256 amount);
    event Unlock(address user, uint256 amount);
    event SetLocker(address locker, bool val);

    function initialize(address _token, uint256 _vestingPeriod)
        external
        initializer
    {
        vestingPeriod = 30 days;
        token = IERC20Upgradeable(_token);
        vestingPeriod = _vestingPeriod > 0 ? _vestingPeriod : vestingPeriod;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setLockers(address[] memory _lockers, bool val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _lockers.length; i++) {
            lockers[_lockers[i]] = val;
            emit SetLocker(_lockers[i], val);
        }
    }

    function unlock(address _addr) public {
        uint256 unlockable = getUnlockable(_addr);
        if (unlockable > 0) {
            vestings[_addr].releasedAmount = vestings[_addr].releasedAmount.add(
                unlockable
            );
            token.safeTransfer(_addr, unlockable);
            emit Unlock(_addr, unlockable);
        }
    }

    function lock(address _addr, uint256 _amount) external {
        //we add this check for avoiding too much vesting
        require(lockers[msg.sender], "only locker can lock");

        token.safeTransferFrom(msg.sender, _addr, _amount);

        // unlock(_addr);

        // if (_amount > 0) {
        //     token.safeTransferFrom(msg.sender, address(this), _amount);
        //     VestingInfo storage vesting = vestings[_addr];
        //     vesting.unlockedFrom = block.timestamp;
        //     vesting.unlockedTo = block.timestamp.add(vestingPeriod);
        //     vesting.totalAmount = vesting.totalAmount.add(_amount);
        //     emit Lock(_addr, _amount);
        // }
    }

    function getUnlockable(address _addr) public view returns (uint256) {
        VestingInfo memory vesting = vestings[_addr];
        if (vesting.totalAmount == 0) {
            return 0;
        }

        if (vesting.unlockedFrom > block.timestamp) return 0;

        uint256 period = vesting.unlockedTo.sub(vesting.unlockedFrom);
        uint256 timeElapsed = block.timestamp.sub(vesting.unlockedFrom);

        uint256 releasable = timeElapsed.mul(vesting.totalAmount).div(period);
        if (releasable > vesting.totalAmount) {
            releasable = vesting.totalAmount;
        }
        return releasable.sub(vesting.releasedAmount);
    }

    function getLockedInfo(address _addr)
        external
        view
        returns (uint256 _locked, uint256 _releasable)
    {
        _releasable = getUnlockable(_addr);
        _locked = vestings[_addr].totalAmount.sub(
            vestings[_addr].releasedAmount
        );
    }
}
