pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./BlackholePreventionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

contract Vesting is
    Initializable,
    BlackholePreventionUpgradeable,
    UUPSUpgradeable,
    ContextUpgradeable,
    OwnableUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct VestingInfo {
        uint256 releasedAmount;
        uint256 totalAmount;
    }

    IERC20Upgradeable public token;
    mapping(address => VestingInfo) public vestings;
    uint256 public startVestingTime;
    uint256 public VESTING_DURATION;

    event Lock(address user, uint256 amount);
    event Unlock(address user, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(address _token, uint256 _startVestingTime)
        public
        initializer
    {
        __Ownable_init();
        __Context_init();

        VESTING_DURATION = 26.8 * 30 days;
        token = IERC20Upgradeable(_token);
        startVestingTime = _startVestingTime == 0
            ? block.timestamp
            : _startVestingTime;
    }

    function setStartVestingTime(uint256 _startVestingTime) external onlyOwner {
        startVestingTime = _startVestingTime;
    }

    function addVesting(address[] memory _addrs, uint256[] memory _amounts)
        external
        onlyOwner
    {
        require(_addrs.length == _amounts.length, "Invalid input length");
        for (uint256 i = 0; i < _addrs.length; i++) {
            vestings[_addrs[i]] = VestingInfo({
                releasedAmount: 0,
                totalAmount: _amounts[i]
            });
            emit Lock(_addrs[i], _amounts[i]);
        }
    }

    function unlock(address _addr) public {
        require(startVestingTime < block.timestamp, "not claimable yet");
        uint256 unlockable = getUnlockableVesting(_addr);
        if (unlockable > 0) {
            vestings[_addr].releasedAmount = vestings[_addr].releasedAmount.add(
                unlockable
            );
            token.safeTransfer(_addr, unlockable);
            emit Unlock(_addr, unlockable);
        }
    }

    function getUnlockable(address _addr) public view returns (uint256) {
        return getUnlockableVesting(_addr);
    }

    function getUnlockableVesting(address _addr) public view returns (uint256) {
        VestingInfo memory vesting = vestings[_addr];
        if (vesting.totalAmount == 0) {
            return 0;
        }

        if (startVestingTime > block.timestamp) return 0;

        uint256 period = VESTING_DURATION;
        uint256 timeElapsed = block.timestamp.sub(startVestingTime);

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
        uint256 remainLocked = 0;
        remainLocked = remainLocked.add(
            vestings[_addr].totalAmount - vestings[_addr].releasedAmount
        );
        _locked = remainLocked.sub(_releasable);
    }

    function getVestingDuration() internal view returns (uint256) {
        return VESTING_DURATION;
    }

    function revoke(address payable _to) external onlyOwner {
        withdrawERC20(_to, address(token), token.balanceOf(address(this)));
    }

    function setVestingDuration(uint256 _a) external onlyOwner {
        VESTING_DURATION = _a;
    }

    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        onlyOwner
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) public virtual onlyOwner {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external virtual onlyOwner {
        _withdrawERC721(receiver, tokenAddress, tokenId);
    }
}
