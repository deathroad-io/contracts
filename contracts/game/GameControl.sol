pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTUsePeriod.sol";
import "../lib/SignerRecover.sol";
import "../farming/TokenVesting.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../lib/BlackholePrevention.sol";

contract GameControl is
    Ownable,
    SignerRecover,
    Initializable,
    BlackholePrevention
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct DepositInfo {
        address depositor;
        uint256 timestamp;
    }

    struct TokenUse {
        uint256 timestamp;
        address user;
    }

    mapping(uint256 => TokenUse) public tokenLastUseTimestamp; //used for prevent from playing more than token frequency
    IDeathRoadNFT public draceNFT;
    IERC20 public drace;
    mapping(uint256 => DepositInfo) public tokenDeposits;
    address public gameOperator;
    TokenVesting public tokenVesting;
    uint256 public gameIndex;
    mapping(address => uint256) public cumulativeRewards;
    mapping(address => uint256[]) public gameIdList;

    event TokenDeposit(address depositor, uint256 tokenId, uint256 timestamp);
    event TokenWithdraw(address withdrawer, uint256 tokenId, uint256 timestamp);

    function initialize(
        address _drace,
        address _draceNFT,
        address _operator,
        address _tokenVesting,
        address _tokenUsePeriodHook
    ) external initializer {
        drace = IERC20(_drace);
        draceNFT = IDeathRoadNFT(_draceNFT);
        gameOperator = _operator;
        tokenVesting = TokenVesting(_tokenVesting);
        tokenUsePeriodHook = INFTUsePeriod(_tokenUsePeriodHook);
    }

    function changeOperator(address _newOperator) external onlyOwner {
        gameOperator = _newOperator;
    }

    function depositNFTsToPlay(uint256[] memory _tokenIds) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            draceNFT.safeTransferFrom(msg.sender, address(this), _tokenIds[i]);
            tokenDeposits[_tokenIds[i]].depositor = msg.sender;
            tokenDeposits[_tokenIds[i]].timestamp = block.timestamp;
            emit TokenDeposit(msg.sender, _tokenIds[i], block.timestamp);
        }
    }

    //withdraw is only available 10 minutes after start playing game
    function withdrawNFTs(uint256[] memory _tokenIds) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (tokenDeposits[_tokenIds[i]].depositor == msg.sender) {
                require(
                    tokenLastUseTimestamp[_tokenIds[i]].timestamp.add(600) <
                        block.timestamp,
                    "game is in play"
                );

                draceNFT.safeTransferFrom(
                    address(this),
                    msg.sender,
                    _tokenIds[i]
                );
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
            }
        }
    }

    function startGame(
        uint256[] memory _tokenIds,
        uint256 _validTimestamp,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(
            _validTimestamp > block.timestamp,
            "signature timestamp too late"
        );
        bytes32 message = keccak256(
            abi.encode(msg.sender, _tokenIds, _validTimestamp)
        );
        address signer = recoverSigner(r, s, v, message);
        require(signer == gameOperator, "invalid operator");

        //verify token ids deposited and not used period a go
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            require(
                tokenDeposits[_tokenIds[i]].depositor == msg.sender,
                "NFT token ID not deposited yet"
            );
            require(
                tokenLastUseTimestamp[_tokenIds[i]].timestamp.add(
                    getUsePeriod(_tokenIds[i])
                ) < block.timestamp,
                "NFT tokens used too frequently"
            );

            //mark last time used
            tokenLastUseTimestamp[_tokenIds[i]].timestamp = block.timestamp;
            tokenLastUseTimestamp[_tokenIds[i]].user = msg.sender;
        }
        gameIdList[msg.sender].push(gameIndex);
        gameIndex++;
    }

    function distributeRewards(
        address _recipient,
        uint256 _rewardAmount,
        uint256 _cumulativeReward,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(
            cumulativeRewards[_recipient].add(_rewardAmount) <=
                _cumulativeReward,
            "reward exceed cumulative rewards"
        );
        //verify signature
        bytes32 message = keccak256(
            abi.encode(_recipient, _rewardAmount, _cumulativeReward)
        );
        address signer = recoverSigner(r, s, v, message);
        require(signer == gameOperator, "distributeRewards::invalid operator");

        cumulativeRewards[_recipient] = cumulativeRewards[_recipient].add(
            _rewardAmount
        );

        //distribute rewards
        //20% released immediately, 80% vested
        uint256 toRelease = _rewardAmount.mul(20).div(100);
        uint256 vesting = _rewardAmount.sub(toRelease);
        drace.safeTransfer(_recipient, toRelease);
        drace.safeApprove(address(tokenVesting), vesting);
        tokenVesting.lock(_recipient, vesting);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        //do nothing
    }

    INFTUsePeriod public tokenUsePeriodHook;

    function setTokenUsePeriodHook(address _addr) external onlyOwner {
        tokenUsePeriodHook = INFTUsePeriod(_addr);
    }

    //each NFT has a period that it can only be used for playing if it was not used for playing more than period ago
    function getUsePeriod(uint256 _tokenId) public view returns (uint256) {
        //the higher level the token id is, the shorter period => users can play more times
        return tokenUsePeriodHook.getNFTUsePeriod(_tokenId, address(draceNFT));
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
