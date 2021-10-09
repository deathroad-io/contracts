pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ITokenLock.sol";

contract TokenLock is Initializable, Ownable, ITokenLock {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct LockInfo {
        bool isWithdrawn;
        address token;
        uint256 unlockableAt;
        uint256 amount;
    }

    mapping(address => LockInfo[]) public lockInfo;
    mapping(address => bool) public lockers;

    event Lock(address token, address user, uint256 amount);
    event Unlock(address token, address user, uint256 amount);
    event SetLocker(address locker, bool val);

    function initialize(address _locker) external initializer {
        lockers[_locker] = true;
        emit SetLocker(_locker, true);
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

    function unlock(address _addr, uint256 index) public override {
        LockInfo[] storage _lockInfo = lockInfo[_addr];
        require(
            !_lockInfo[index].isWithdrawn &&
                _lockInfo[index].unlockableAt <= block.timestamp,
            "Already withdrawn or not unlockable yet"
        );
        _lockInfo[index].isWithdrawn = true;
        IERC20(_lockInfo[index].token).safeTransfer(
            _addr,
            _lockInfo[index].amount
        );
        emit Unlock(_lockInfo[index].token, _addr, _lockInfo[index].amount);

        //remove the unlocked index
        _lockInfo[index] = _lockInfo[_lockInfo.length - 1];
        _lockInfo.pop();
    }

    function lock(
        address _token,
        address _addr,
        uint256 _amount,
        uint256 _lockedTime
    ) external override {
        //we add this check for avoiding too much vesting
        require(lockers[msg.sender], "only locker can lock");
        if (_amount > 0) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

            lockInfo[_addr].push(
                LockInfo({
                    isWithdrawn: false,
                    token: _token,
                    unlockableAt: block.timestamp + _lockedTime,
                    amount: _amount
                })
            );

            emit Lock(_token, _addr, _amount);
        }
    }

    function getLockInfo(address _user)
        external
        view
        override
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        )
    {
        uint256 length = lockInfo[_user].length;
        LockInfo[] memory lockedInfo = lockInfo[_user];
        isWithdrawns = new bool[](length);
        unlockableAts = new uint256[](length);
        amounts = new uint256[](length);
        tokens = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            isWithdrawns[i] = lockedInfo[i].isWithdrawn;
            unlockableAts[i] = lockedInfo[i].unlockableAt;
            amounts[i] = lockedInfo[i].amount;
            tokens[i] = lockedInfo[i].token;
        }
    }

    function getLockInfoByIndexes(address _addr, uint256[] memory _indexes)
        external
        view
        override
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        )
    {
        uint256 length = _indexes.length;
        LockInfo[] memory lockedInfo = lockInfo[_addr];
        isWithdrawns = new bool[](length);
        unlockableAts = new uint256[](length);
        amounts = new uint256[](length);
        tokens = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            isWithdrawns[i] = lockedInfo[_indexes[i]].isWithdrawn;
            unlockableAts[i] = lockedInfo[_indexes[i]].unlockableAt;
            amounts[i] = lockedInfo[_indexes[i]].amount;
            tokens[i] = lockedInfo[i].token;
        }
    }

    function getLockInfoLength(address _addr)
        external
        view
        override
        returns (uint256)
    {
        return lockInfo[_addr].length;
    }    
}
