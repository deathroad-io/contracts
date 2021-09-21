pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./BlackholePrevention.sol";
import "./SignerRecover.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract AirdropDistribution is Ownable, BlackholePrevention, Initializable, SignerRecover {
    using SafeERC20 for IERC20;
    uint256 public claimCount;
    address public validator;
    IERC20 public drace;
    struct UserInfo {
        uint256 total;
        uint256 claimed;
        uint256 claimCount;
    }

    mapping(address => UserInfo) public userInfo;

    function initialize(address _drace, address _validator) public initializer {
        validator = _validator;
        drace = IERC20(_drace);
    }

    function setClaimCount(uint256 _claimCount) external onlyOwner {
        claimCount = _claimCount;
    }

    function claim(uint256 _total, uint256 _toClaim, bytes32 r, bytes32 s, uint8 v) external {
        UserInfo storage _user = userInfo[msg.sender];
        require(claimCount == _user.claimCount + 1, "Your airdrop was burnt as you did not claim last time");

        bytes32 message = keccak256(abi.encode(
            msg.sender, 
            _total,
            _toClaim,
            claimCount
        ));

        require(validator == recoverSigner(r, s, v, message), "Invalid validator");

        if (_user.claimCount > 0) {
            //claim second, third, ford times
            require(_user.total >= _total, "Over claim total amount");
        }

        _user.claimCount = _user.claimCount + 1;
        _user.claimed = _user.claimed + _toClaim;
        require(_user.claimed <= _total, "Over claimed exceed total amount");
        _user.total = _total;

        drace.safeTransfer(msg.sender, _toClaim);
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