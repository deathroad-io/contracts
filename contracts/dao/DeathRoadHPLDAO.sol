pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/IMint.sol";
import "../interfaces/INFTCountdown.sol";
import "../lib/SignerRecover.sol";
import "../interfaces/ITokenVesting.sol";
import "../interfaces/IxDraceDistributor.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../lib/BlackholePrevention.sol";
import "../interfaces/IReferralContract.sol";

contract DeathRoadHPLDAO is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    SignerRecover,
    BlackholePrevention
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    IERC20Upgradeable public paymentToken;
    address public operator;
    uint public totalContributed;

    struct UserInfo {
        uint256 contributed;
        address user;
    }

    mapping(address => UserInfo) public userInfo;

    event Contributed(address user, uint amount);

    function initialize(address _paymentToken, address _operator) external initializer {
        __Ownable_init();
        __Context_init();
        paymentToken = IERC20Upgradeable(_paymentToken);
        operator = _operator;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function purchaseToken(uint _paymentTokenAmount, uint _maxAmount, uint _deadline, bytes32 _r, bytes32 _s, uint8 _v) external {
        require(_deadline > block.timestamp, "expired");
        
        bytes32 message = keccak256(
            abi.encode(msg.sender, _paymentTokenAmount, _maxAmount, _deadline)
        );

        require(
            operator == recoverSigner(_r, _s, _v, message),
            "Invalid operator"
        );
        
        paymentToken.safeTransferFrom(msg.sender, address(this), _paymentTokenAmount);

        userInfo[msg.sender].user = msg.sender;
        userInfo[msg.sender].contributed = userInfo[msg.sender].contributed.add(_paymentTokenAmount);

        emit Contributed(msg.sender, _paymentTokenAmount);

        totalContributed = totalContributed.add(_paymentTokenAmount);

        require(userInfo[msg.sender].contributed <= _maxAmount, "exceeds max contribution");
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
