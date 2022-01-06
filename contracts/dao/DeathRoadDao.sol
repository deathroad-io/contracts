pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/IMint.sol";
import "../interfaces/INFTCountdown.sol";
import "../lib/SignerRecover.sol";
import "../interfaces/ITokenVesting.sol";
import "../interfaces/IxDraceDistributor.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../lib/BlackholePreventionUpgradeable.sol";
import "../interfaces/IReferralContract.sol";

contract DeathRoadDao is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    SignerRecover,
    BlackholePreventionUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address payable;
    address public paymentToken;
    address public operator;
    uint256 public totalContributed;
    string public poolName;
    address[] public contributors;

    struct UserInfo {
        uint256 contributed;
        address user;
        uint256 refunded;
    }

    mapping(address => UserInfo) public userInfo;
    uint256 public refundStartTime;
    uint256 public claimStartTime;
    address public token;

    event Contributed(address user, uint256 amount);
    event Refund(address user, uint256 amount);

    function initialize(
        string memory _poolName,
        address _paymentToken,
        address _operator
    ) external initializer {
        __Ownable_init();
        __Context_init();
        poolName = _poolName;
        paymentToken = _paymentToken;
        operator = _operator;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function purchaseToken(
        uint256 _paymentTokenAmount,
        uint256 _maxAmount,
        uint256 _deadline,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) external payable {
        require(_deadline > block.timestamp, "expired");
        bytes32 message = keccak256(
            abi.encode(
                address(this),
                msg.sender,
                _paymentTokenAmount,
                _maxAmount,
                _deadline
            )
        );

        require(
            operator == recoverSigner(_r, _s, _v, message),
            "Invalid operator"
        );

        if (isNativeToken(paymentToken)) {
            require(
                msg.value == _paymentTokenAmount,
                "invalid native payment amount"
            );
        } else {
            IERC20Upgradeable(paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                _paymentTokenAmount
            );
        }

        userInfo[msg.sender].user = msg.sender;
        if (userInfo[msg.sender].contributed == 0) {
            contributors.push(msg.sender);
        }
        userInfo[msg.sender].contributed = userInfo[msg.sender].contributed.add(
            _paymentTokenAmount
        );

        totalContributed = totalContributed.add(_paymentTokenAmount);

        require(
            userInfo[msg.sender].contributed <= _maxAmount,
            "exceeds max contribution"
        );

        emit Contributed(msg.sender, _paymentTokenAmount);
    }

    function setTimestamps(uint256 _refund, uint256 _claim) external onlyOwner {
        refundStartTime = _refund;
        claimStartTime = _claim;
    }

    function setToken(address _token) external onlyOwner {
        token = _token;
    }

    function refund(
        address _addr,
        uint256 _amount,
        uint256 _deadline,
        bytes32 _r,
        bytes32 _s,
        uint8 _v
    ) external {
        require(
            refundStartTime > 0 && refundStartTime < block.timestamp,
            "not refund time"
        );
        require(_deadline > block.timestamp, "expired");
        bytes32 message = keccak256(
            abi.encode(address(this), _addr, _amount, _deadline)
        );

        require(
            operator == recoverSigner(_r, _s, _v, message),
            "Invalid operator"
        );

        require(
            userInfo[_addr].refunded <= _amount,
            "refunded amount too high"
        );

        require(
            _amount <= userInfo[_addr].contributed,
            "refunded amount is higher than contributed"
        );
        uint256 toTransfer = _amount - userInfo[_addr].refunded;
        userInfo[_addr].refunded = _amount;
        if (toTransfer > 0) {
            if (isNativeToken(paymentToken)) {
                payable(_addr).sendValue(toTransfer);
            } else {
                IERC20Upgradeable(paymentToken).safeTransfer(_addr, toTransfer);
            }
            emit Refund(_addr, toTransfer);
        }
    }

    function claimToken() external {
        require(
            claimStartTime > 0 && claimStartTime < block.timestamp,
            "not refund time"
        );
    }

    function getContributors() external view returns (address[] memory) {
        return contributors;
    }

    function isNativeToken(address _addr) public pure returns (bool) {
        return _addr == address(0x1111111111111111111111111111111111111111);
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
