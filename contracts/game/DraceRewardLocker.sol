pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract DraceRewardLocker is
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
        uint256 groupPeriod;
    }
    uint256 public cliffPeriod;
    uint256 public vestingPeriod;
    IERC20Upgradeable public token;
    mapping(address => VestingInfo[]) public vestings;
    mapping(address => bool) public lockers;

    event Lock(address user, uint256 amount);
    event Unlock(address user, uint256 amount);
    event SetLocker(address locker, bool val);

    function changeCliffPeriod(uint256 _cliff) external onlyOwner {
        cliffPeriod = _cliff;
    }

    function initialize(address _token, uint256 _vestingPeriod)
        external
        initializer
    {
        __Ownable_init();
        __Context_init();
        cliffPeriod = 1 days;
        vestingPeriod = 30 days;
        token = IERC20Upgradeable(_token);
        vestingPeriod = _vestingPeriod > 0 ? _vestingPeriod : vestingPeriod;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function changeVestingPeriod(uint256 _vestingPeriod) external onlyOwner {
        vestingPeriod = _vestingPeriod;
    }

    function setLockers(address[] memory _lockers, bool val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _lockers.length; i++) {
            lockers[_lockers[i]] = val;
            emit SetLocker(_lockers[i], val);
        }
    }

    function unlock(address _addr, uint256[] memory _indexes) public {
        uint256 totalUnlockable = 0;
        for (uint256 i = 0; i < _indexes.length; i++) {
            uint256 unlockable = getUnlockableVesting(_addr, _indexes[i]);
            if (unlockable > 0) {
                vestings[_addr][_indexes[i]].releasedAmount = vestings[_addr][
                    _indexes[i]
                ].releasedAmount.add(unlockable);
                totalUnlockable = totalUnlockable.add(unlockable);
            }
        }
        token.safeTransfer(_addr, totalUnlockable);
        emit Unlock(_addr, totalUnlockable);
    }

    function lock(address _addr, uint256 _amount) external {
        //we add this check for avoiding too much vesting
        require(lockers[msg.sender], "only locker can lock");
        if (_amount > 0) {
            token.safeTransferFrom(msg.sender, _addr, _amount);
            //token.safeTransferFrom(msg.sender, address(this), _amount);

            // VestingInfo[] storage _vs = vestings[_addr];
            // if (_vs.length > 0) {
            //     //to avoid having too much elements in vesting, we group all vesting within time frame from unlockedFrom til groupPeriod
            //     //for example, rewards in day 1 and day 5 will be grouped
            //     VestingInfo storage lastVesting = _vs[_vs.length - 1];
            //     if (
            //         lastVesting.unlockedFrom.add(lastVesting.groupPeriod) >
            //         block.timestamp.add(cliffPeriod)
            //     ) {
            //         lastVesting.totalAmount = lastVesting.totalAmount.add(
            //             _amount
            //         );
            //     } else {
            //         //create new vesting
            //         _vs.push(
            //             VestingInfo({
            //                 unlockedFrom: block.timestamp.add(cliffPeriod),
            //                 unlockedTo: block.timestamp.add(cliffPeriod).add(
            //                     vestingPeriod
            //                 ),
            //                 releasedAmount: 0,
            //                 totalAmount: _amount,
            //                 groupPeriod: cliffPeriod / 2
            //             })
            //         );
            //     }
            // } else {
            //     _vs.push(
            //         VestingInfo({
            //             unlockedFrom: block.timestamp.add(cliffPeriod),
            //             unlockedTo: block.timestamp.add(cliffPeriod).add(
            //                 vestingPeriod
            //             ),
            //             releasedAmount: 0,
            //             totalAmount: _amount,
            //             groupPeriod: cliffPeriod / 2
            //         })
            //     );
            // }

            // emit Lock(_addr, _amount);
        }
    }

    function getUnlockable(address _addr) external view returns (uint256) {
        uint256 ret = 0;
        uint256 l = vestings[_addr].length;
        for (uint256 i = 0; i < l; i++) {
            ret = ret.add(getUnlockableVesting(_addr, i));
        }
        return ret;
    }

    function getUnlockableVesting(address _addr, uint256 _index)
        public
        view
        returns (uint256)
    {
        if (_index >= vestings[_addr].length) return 0;
        VestingInfo memory vesting = vestings[_addr][_index];
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

    function getUserVestingLength(address _user)
        external
        view
        returns (uint256)
    {
        return vestings[_user].length;
    }
}
