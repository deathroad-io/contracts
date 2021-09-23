pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./BlackholePrevention.sol";
import "./SignerRecover.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LinearAirdrop is
    Ownable,
    BlackholePrevention,
    Initializable,
    SignerRecover
{
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    uint256 public claimCount;
    address public validator;
    IERC20 public drace;
    uint256 public startClaimTimestamp;
    uint256 public constant VESTING_INIT_PERIOD = 2 days;
    uint256 public constant VESTING_PERIOD = 30 days;
    struct Vesting {
        uint256 amount;
        uint256 claimed;
        uint256 from;
        uint256 to;
        uint256 endClaimTimestamp;
    }

    mapping(address => Vesting[]) public vestings;

    function initialize(
        address _drace,
        address _validator
    ) public initializer {
        validator = _validator;
        drace = IERC20(_drace);
    }

    function setStartClaimTimestamp(uint256 _t) external onlyOwner {
        startClaimTimestamp = _t > 0 ? _t : block.timestamp;
    }

    function changeValidator(address _newValidator) public onlyOwner {
        validator = _newValidator;
    }

    function claim(
        uint256 _total,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        bytes32 message = keccak256(abi.encode(msg.sender, _total));

        require(
            validator == recoverSigner(r, s, v, message),
            "Invalid validator"
        );

        _claim(_total);
    }

    function _claim(uint256 _total) internal {
        require(startClaimTimestamp > 0, "wait for starting claim");

        _initVesting(_total);

        claimAllClaimable();
    }

    function claimAllClaimable() public {
        Vesting[] storage _vestings = vestings[msg.sender];
        require(
            _vestings.length > 0,
            "Your airdrop was burnt due to not init vesting on time"
        );

        for (uint256 i = 0; i < _vestings.length; i++) {
            claimVesting(i);
        }
    }

    function claimVesting(uint256 _index) public {
        Vesting storage _vesting = vestings[msg.sender][_index];
        if (
            !(_vesting.from <= block.timestamp &&
                _vesting.endClaimTimestamp >= block.timestamp)
        ) {
            return;
        }

        uint256 claimableTilNow = ((block.timestamp - _vesting.from) *
            _vesting.amount) / VESTING_PERIOD;

        if (claimableTilNow > _vesting.amount) {
            claimableTilNow = _vesting.amount;
        }

        uint256 _toTransfer = claimableTilNow.sub(_vesting.claimed);

        _vesting.claimed = claimableTilNow;
        if (_toTransfer > 0) {
            drace.safeTransfer(msg.sender, _toTransfer);
        }
    }

    function getUserStatus(address _user)
        external
        view
        returns (uint256 _claimable, uint256 _lock, uint256 _total)
    {
        Vesting[] storage _vestings = vestings[_user];
        if (_vestings.length == 0) return (0, 0, 0);

        for (uint256 i = 0; i < _vestings.length; i++) {
            Vesting storage _vesting = _vestings[i];
            if (_vesting.from > block.timestamp) {
                _lock = _lock.add(_vesting.amount);
                continue;
            }

            if (_vesting.endClaimTimestamp < block.timestamp) {
                continue;
            }

            uint256 claimableTilNow = ((block.timestamp - _vesting.from) *
                _vesting.amount) / VESTING_PERIOD;

            if (claimableTilNow > _vesting.amount) {
                claimableTilNow = _vesting.amount;
            }

            _claimable = _claimable.add(claimableTilNow.sub(_vesting.claimed));
            _lock = _lock.add(_vesting.amount.sub(claimableTilNow));
        }
        _total = _claimable + _lock;
    }

    function _initVesting(uint256 _total) private {
        Vesting[] storage _vestings = vestings[msg.sender];
        if (
            _vestings.length == 0 &&
            startClaimTimestamp.add(VESTING_INIT_PERIOD) >= block.timestamp
        ) {
            //not init yet, and still in init vesting period
            uint256 l = 4;
            uint256 amount = _total / l;
            _vestings.push(
                Vesting({
                    amount: amount,
                    claimed: 0,
                    from: startClaimTimestamp,
                    to: startClaimTimestamp + VESTING_PERIOD,
                    endClaimTimestamp: startClaimTimestamp +
                        VESTING_PERIOD +
                        VESTING_INIT_PERIOD
                })
            );

            //cliff 1 month

            _vestings.push(
                Vesting({
                    amount: amount,
                    claimed: 0,
                    from: startClaimTimestamp + 2 * VESTING_PERIOD,
                    to: startClaimTimestamp + 3 * VESTING_PERIOD,
                    endClaimTimestamp: startClaimTimestamp +
                        3 *
                        VESTING_PERIOD +
                        VESTING_INIT_PERIOD
                })
            );

            _vestings.push(
                Vesting({
                    amount: amount,
                    claimed: 0,
                    from: startClaimTimestamp + 3 * VESTING_PERIOD,
                    to: startClaimTimestamp + 4 * VESTING_PERIOD,
                    endClaimTimestamp: startClaimTimestamp +
                        4 *
                        VESTING_PERIOD +
                        VESTING_INIT_PERIOD
                })
            );

            _vestings.push(
                Vesting({
                    amount: amount,
                    claimed: 0,
                    from: startClaimTimestamp + 4 * VESTING_PERIOD,
                    to: startClaimTimestamp + 5 * VESTING_PERIOD,
                    endClaimTimestamp: startClaimTimestamp +
                        5 *
                        VESTING_PERIOD +
                        VESTING_INIT_PERIOD
                })
            );
        }
    }

    function didYouMakeInitialClaim(address _addr) external view returns (bool) {
        return vestings[_addr].length > 0;
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
    ) external virtual onlyOwner {
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
