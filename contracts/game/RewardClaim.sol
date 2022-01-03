pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
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
import "../lib/BlackholePreventionUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "../interfaces/IReferralContract.sol";

contract RewardClaim is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    SignerRecover,
    BlackholePreventionUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct ReferralRewards {
        uint256 totalDrace;
        uint256 totalxDrace;
    }

    struct UserRewardInfo {
        uint256 claimedDrace;
        uint256 claimedxDrace;
        uint256 lastClaimedGameId;
        uint256 lastClaimedRoomIndex;
    }

    IERC20Upgradeable public drace;
    IERC20Upgradeable public xdrace;

    mapping(address => bool) public mappingApprover;
    ITokenVesting public tokenVesting;
    IxDraceDistributor public xDraceVesting;

    mapping(address => UserRewardInfo) public claimedRewards;

    IReferralContract public referralHook;
    uint256 public draceReferralPercentX100; //per 10000, 10 => 100 *10/10000 = 0.1%
    uint256 public xdraceReferralPercentX100;
    mapping(address => ReferralRewards) public totalReferralRewards;

    uint256 public chainId;

    event RewardDistribution(
        address player,
        uint256 draceReward,
        uint256 xdraceReward,
        uint256 timestamp
    );

    event ReferralReward(
        address player,
        address referrer,
        uint256 draceAmount,
        uint256 xDraceAmount
    );

    function initialize(
        address _drace,
        address _approver,
        address _tokenVesting,
        address _xdrace,
        address _xDraceVesting,
        address _referralHook
    ) external initializer {
        __Ownable_init();
        __Context_init();

        drace = IERC20Upgradeable(_drace);
        tokenVesting = ITokenVesting(_tokenVesting);
        xdrace = IERC20Upgradeable(_xdrace);
        if (_approver != address(0)) {
            mappingApprover[_approver] = true;
        }
        xDraceVesting = IxDraceDistributor(_xDraceVesting);

        uint256 _cid;
        assembly {
            _cid := chainid()
        }
        chainId = _cid;
        referralHook = IReferralContract(_referralHook);
        draceReferralPercentX100 = 20;
        xdraceReferralPercentX100 = 30;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setReferralPercent(
        uint256 _draceReferralPercentX100,
        uint256 _xdraceReferralPercentX100
    ) external onlyOwner {
        draceReferralPercentX100 = _draceReferralPercentX100;
        xdraceReferralPercentX100 = _xdraceReferralPercentX100;
    }

    function setReferralHook(address _referralHook) external onlyOwner {
        referralHook = IReferralContract(_referralHook);
    }

    function setTokenVesting(address _vesting) external onlyOwner {
        tokenVesting = ITokenVesting(_vesting);
    }

    function setXDraceVesting(address _vesting) external onlyOwner {
        xDraceVesting = IxDraceDistributor(_vesting);
    }

    function addApprover(address _approver, bool _val) public onlyOwner {
        mappingApprover[_approver] = _val;
    }

    function distributeRewards(
        address _recipient,
        uint256 _totalDraceAmount,
        uint256 _totalxDraceAmount,
        uint256 _lastGameIdToClaim,
        uint256 _lastRoomIndexToClaim,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        //verify signature
        bytes32 message = keccak256(
            abi.encode(
                _recipient,
                _totalDraceAmount,
                _totalxDraceAmount,
                _lastGameIdToClaim,
                _lastRoomIndexToClaim
            )
        );

        require(
            verifySigner(message, r, s, v),
            "distributeRewards::invalid operator"
        );

        _distribute(
            _recipient,
            _totalDraceAmount,
            _totalxDraceAmount,
            _lastGameIdToClaim,
            _lastRoomIndexToClaim
        );
    }

    function verifySigner(
        bytes32 message,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal view returns (bool) {
        address signer = recoverSigner(r, s, v, message);
        return mappingApprover[signer];
    }

    //to save gas, we allow to claim rewards fro a range of game ids
    function _distribute(
        address _recipient,
        uint256 _totalDraceAmount,
        uint256 _totalxDraceAmount,
        uint256 _lastGameIdToClaim,
        uint256 _lastRoomIndexToClaim
    ) internal {
        UserRewardInfo storage _userInfo = claimedRewards[_recipient];
        require(
            _lastGameIdToClaim >= _userInfo.lastClaimedGameId,
            "!lastClaimedGameId"
        );
        require(
            _lastRoomIndexToClaim >= _userInfo.lastClaimedRoomIndex,
            "!lastClaimedRoomIndex"
        );
        //compute drace and xdrace to claim
        uint256 _draceAmount = _totalDraceAmount.sub(_userInfo.claimedDrace);
        uint256 _xdraceAmount = _totalxDraceAmount.sub(_userInfo.claimedxDrace);

        _userInfo.claimedDrace = _totalDraceAmount;
        _userInfo.claimedxDrace = _totalxDraceAmount;
        _userInfo.lastClaimedGameId = _lastGameIdToClaim;
        _userInfo.lastClaimedRoomIndex = _lastRoomIndexToClaim;

        //distribute rewards
        //xDRACE% released immediately, drace vested
        drace.safeApprove(address(tokenVesting), _draceAmount);
        tokenVesting.lock(_recipient, _draceAmount);

        IMint(address(xdrace)).mint(address(this), _xdraceAmount);
        IERC20Upgradeable(address(xdrace)).approve(
            address(xDraceVesting),
            _xdraceAmount
        );
        xDraceVesting.lock(_recipient, _xdraceAmount);

        //sending rewards to referrer
        if (address(referralHook) != address(0)) {
            (address _referrer, bool _canReceive) = referralHook.getReferrer(
                _recipient
            );
            if (_canReceive) {
                if (_referrer != _recipient) {
                    if (draceReferralPercentX100 > 0) {
                        drace.safeTransfer(
                            _referrer,
                            _draceAmount.mul(draceReferralPercentX100).div(
                                10000
                            )
                        );
                        totalReferralRewards[_referrer]
                            .totalDrace += _draceAmount
                            .mul(draceReferralPercentX100)
                            .div(10000);
                    }

                    if (xdraceReferralPercentX100 > 0) {
                        IMint(address(xdrace)).mint(
                            _referrer,
                            _xdraceAmount.mul(xdraceReferralPercentX100).div(
                                10000
                            )
                        );
                        totalReferralRewards[_referrer]
                            .totalxDrace += _xdraceAmount
                            .mul(xdraceReferralPercentX100)
                            .div(10000);
                    }
                    emit ReferralReward(
                        _recipient,
                        _referrer,
                        _draceAmount.mul(draceReferralPercentX100).div(10000),
                        _xdraceAmount.mul(xdraceReferralPercentX100).div(10000)
                    );
                }
            }
        }

        emit RewardDistribution(
            _recipient,
            _draceAmount,
            _xdraceAmount,
            block.timestamp
        );
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
