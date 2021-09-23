pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/IMint.sol";
import "../interfaces/INFTCountdown.sol";
import "../lib/SignerRecover.sol";
import "../interfaces/ITokenVesting.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../lib/BlackholePrevention.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract GameControl is
    Ownable,
    SignerRecover,
    Initializable,
    BlackholePrevention,
    IERC721Receiver
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    struct DepositInfo {
        address depositor;
        uint256 timestamp;
        uint256 tokenId;
    }

    struct TokenUse {
        uint256 timestamp;
        address user;
        uint256 tokenId;
    }

    struct GameIdInfo {
        bool isRewardPaid;
        address player;
        uint256 gameId;
    }
    address public feeTo;

    mapping(uint256 => TokenUse) public tokenLastUseTimestamp; //used for prevent from playing more than token frequency
    IDeathRoadNFT public draceNFT;
    IERC20 public drace;
    IERC20 public xdrace;
    mapping(uint256 => DepositInfo) public tokenDeposits;
    mapping(address => uint256[]) public depositTokenList;

    //approvers will verify whether:
    //1. Game is in maintenance or not
    //2. Users are using at least one car and one gun in the token id list
    mapping(address => bool) public mappingApprover;
    ITokenVesting public tokenVesting;
    uint256 public gameCount;
    mapping(address => uint256) public cumulativeRewards;
    mapping(address => uint256[]) public gameIdList; //list of game id users play
    mapping(uint256 => GameIdInfo) public gameIdToPlayer;
    mapping(address => uint256) public playerGameCounts; //game count for each user

    mapping(uint256 => uint256) public tokenPlayingTurns;
    mapping(uint256 => bool) public isFreePlayingTurnsAdded;

    uint256 public constant FREE_PLAYING_TURNS = 20;

    uint256 public xDracePercent = 70;

    INFTFactory public factory;

    event TokenDeposit(address depositor, uint256 tokenId, uint256 timestamp);
    event TokenWithdraw(address withdrawer, uint256 tokenId, uint256 timestamp);
    event GameStart(
        address player,
        bytes tokenIds,
        uint256 timestamp,
        uint256 playerGameCount,
        uint256 globalGameCount
    );

    event TurnBuying(address payer, uint256 tokenId, uint256 price, uint256 timestamp);
    event RewardDistribution(address player, bytes gameIds, uint256 draceReward, uint256 xdraceReward, uint256 timestamp);
    function initialize(
        address _drace,
        address _draceNFT,
        address _approver,
        address _tokenVesting,
        address _countdownPeriod,
        address _factory,
        address _xdrace
    ) external initializer {
        drace = IERC20(_drace);
        draceNFT = IDeathRoadNFT(_draceNFT);
        mappingApprover[_approver] = true;
        tokenVesting = ITokenVesting(_tokenVesting);
        countdownPeriod = INFTCountdown(_countdownPeriod);
        factory = INFTFactory(_factory);
        xdrace = IERC20(_xdrace);
    }

    function setTokenVesting(address _vesting) external onlyOwner {
        tokenVesting = ITokenVesting(_vesting);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setXDracePercent(uint256 _p) external onlyOwner {
        xDracePercent = _p;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = INFTFactory(_factory);
    }

    function addApprover(address _approver, bool _val) public onlyOwner {
        mappingApprover[_approver] = _val;
    }

    function depositNFTsToPlay(uint256[] memory _tokenIds) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            draceNFT.transferFrom(msg.sender, address(this), _tokenIds[i]);
            tokenDeposits[_tokenIds[i]].depositor = msg.sender;
            tokenDeposits[_tokenIds[i]].timestamp = block.timestamp;
            tokenDeposits[_tokenIds[i]].tokenId = _tokenIds[i];
            depositTokenList[msg.sender].push(_tokenIds[i]);
            emit TokenDeposit(msg.sender, _tokenIds[i], block.timestamp);
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
        require(mappingApprover[signer], "invalid operator");

        _startGame(_tokenIds);
    }

    function _checkOrAddFreePlayingTurns(uint256 _tokenId) internal {
        if (!isFreePlayingTurnsAdded[_tokenId]) {
            isFreePlayingTurnsAdded[_tokenId] = true;
            tokenPlayingTurns[_tokenId] = tokenPlayingTurns[_tokenId].add(FREE_PLAYING_TURNS);
        }
    }

    function _startGame(uint256[] memory _tokenIds) internal {
        //verify token ids deposited and not used period a go
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            //check token deposited, if not, deposit it
            if (tokenDeposits[_tokenIds[i]].depositor != msg.sender) {
                //not deposit yet
                draceNFT.transferFrom(msg.sender, address(this), _tokenIds[i]);
                tokenDeposits[_tokenIds[i]].depositor = msg.sender;
                tokenDeposits[_tokenIds[i]].timestamp = block.timestamp;
                tokenDeposits[_tokenIds[i]].tokenId = _tokenIds[i];
                depositTokenList[msg.sender].push(_tokenIds[i]);
                emit TokenDeposit(msg.sender, _tokenIds[i], block.timestamp);
            }
            require(
                tokenLastUseTimestamp[_tokenIds[i]].timestamp.add(
                    getCountdownPeriod(_tokenIds[i])
                ) < block.timestamp,
                "NFT tokens used too frequently"
            );
            _checkOrAddFreePlayingTurns(_tokenIds[i]);
            require(tokenPlayingTurns[_tokenIds[i]] > 0, "No playing turn left");
            
            //mark last time used
            tokenLastUseTimestamp[_tokenIds[i]].timestamp = block.timestamp;
            tokenLastUseTimestamp[_tokenIds[i]].user = msg.sender;
            tokenLastUseTimestamp[_tokenIds[i]].tokenId = _tokenIds[i];
            tokenPlayingTurns[_tokenIds[i]] = tokenPlayingTurns[_tokenIds[i]].sub(1);
        }

        emit GameStart(
            msg.sender,
            abi.encode(_tokenIds),
            block.timestamp,
            playerGameCounts[msg.sender],
            gameCount
        );

        gameIdList[msg.sender].push(gameCount);
        gameIdToPlayer[gameCount] = GameIdInfo({
            isRewardPaid: false,
            player: msg.sender,
            gameId: gameCount
        });
        playerGameCounts[msg.sender]++;
        gameCount++;
    }

    function distributeRewards(
        address _recipient,
        uint256 _draceAmount,
        uint256 _xdraceAmount,
        uint256 _cumulativeReward,
        uint256[] memory _gameIds,
        bytes32 r,
        bytes32 s,
        uint8 v,
        bool _withdrawNFTs
    ) external {
        //verify signature
        bytes32 message = keccak256(
            abi.encode(_recipient, _draceAmount, _xdraceAmount, _cumulativeReward, _gameIds)
        );
        address signer = recoverSigner(r, s, v, message);
        require(mappingApprover[signer], "distributeRewards::invalid operator");

        _distribute(_recipient, _draceAmount, _xdraceAmount, _cumulativeReward, _gameIds);

        if (_withdrawNFTs) {
            withdrawAllNFTs();
        }
    }

    function withdrawAllNFTs() public {
        uint256[] memory _tokenIds = depositTokenList[msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (tokenDeposits[_tokenIds[i]].depositor == msg.sender) {
                require(
                    tokenLastUseTimestamp[_tokenIds[i]].timestamp.add(600) <
                        block.timestamp,
                    "game is in play"
                );

                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
            }
        }
        delete depositTokenList[msg.sender];
    }

    function withdrawNFT(uint256 _tokenId) external {
        require(tokenDeposits[_tokenId].depositor == msg.sender, "withdrawNFT: NFT not yours");

        uint256[] memory _tokenIds = depositTokenList[msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_tokenId == _tokenIds[0]) {
                require(
                    tokenLastUseTimestamp[_tokenIds[i]].timestamp.add(600) <
                        block.timestamp,
                    "game is in play"
                );
                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
                depositTokenList[msg.sender][i] = depositTokenList[msg.sender][_tokenIds.length - 1];
                depositTokenList[msg.sender].pop();
                return;
            }
        }
    }

    //to save gas, we allow to claim rewards fro a range of game ids
    function _distribute(
        address _recipient,
        uint256 _draceAmount,
        uint256 _xdraceAmount,
        uint256 _cumulativeReward,
        uint256[] memory _gameIds
    ) internal {
        for(uint256 i = 0; i < _gameIds.length; i++) {
            require(!gameIdToPlayer[_gameIds[i]].isRewardPaid, "rewards already paid");
            gameIdToPlayer[_gameIds[i]].isRewardPaid = true;
        }
        require(
            cumulativeRewards[_recipient].add(_draceAmount) <=
                _cumulativeReward,
            "reward exceed cumulative rewards"
        );
        cumulativeRewards[_recipient] = cumulativeRewards[_recipient].add(
            _draceAmount
        );

        //distribute rewards
        //xDRACE% released immediately, drace vested
        drace.safeApprove(address(tokenVesting), _draceAmount);
        tokenVesting.lock(_recipient, _draceAmount);

        IMint(address(xdrace)).mint(_recipient, _xdraceAmount);

        emit RewardDistribution(_recipient, abi.encode(_gameIds), _draceAmount, _xdraceAmount, block.timestamp);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        //do nothing
        return bytes4("");
    }

    INFTCountdown public countdownPeriod;

    function setCountdownHook(address _addr) external onlyOwner {
        countdownPeriod = INFTCountdown(_addr);
    }

    function buyPlayingTurn(
        uint256 _tokenId,
        uint256 _price, //price per turn
        uint256 _turnCount,
        bool _usexDrace,
        uint256 _expiry,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        uint256 _totalFee = _turnCount * _price;
        if (_usexDrace) {
            uint256 xDraceNeeded = _totalFee.mul(xDracePercent).div(100);

            drace.safeTransferFrom(msg.sender, feeTo, _totalFee.sub(xDraceNeeded));
            ERC20Burnable(address(xdrace)).burnFrom(msg.sender, xDraceNeeded);  //burn xDrace immediately
        } else {
            drace.safeTransferFrom(msg.sender, feeTo, _totalFee);
        }
        bytes32 message = keccak256(
            abi.encode("buyPlayingTurn", _tokenId, _price, _turnCount, _usexDrace, _expiry)
        );
        address signer = recoverSigner(r, s, v, message);
        require(mappingApprover[signer], "buyPlayingTurn::invalid operator");

        _checkOrAddFreePlayingTurns(_tokenId);
        tokenPlayingTurns[_tokenId] = tokenPlayingTurns[_tokenId].add(_turnCount);
        //reset timestamp
        tokenLastUseTimestamp[_tokenId].timestamp = 0;
        emit TurnBuying(msg.sender, _tokenId, _price, block.timestamp);
    }

    //each NFT has a period that it can only be used for playing if it was not used for playing more than period ago
    function getCountdownPeriod(uint256 _tokenId)
        public
        view
        returns (uint256)
    {
        //the higher level the token id is, the shorter period => users can play more times
        return countdownPeriod.getCountdownPeriod(_tokenId, address(draceNFT));
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
