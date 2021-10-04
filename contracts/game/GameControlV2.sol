pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/IMint.sol";
import "../interfaces/INFTCountdown.sol";
import "../lib/SignerRecover.sol";
import "../interfaces/ITokenVesting.sol";
import "../interfaces/IxDraceDistributor.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../lib/BlackholePrevention.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract GameControlV2 is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    SignerRecover,
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

    struct GameIdInfo {
        bool isRewardPaid;
        address player;
        uint256 gameId;
    }
    address public feeTo;

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
    IxDraceDistributor public xDraceVesting;
    uint256 public gameCount;
    mapping(address => uint256) public cumulativeRewards;

    mapping(uint256 => uint256) public tokenPlayingTurns;
    mapping(uint256 => bool) public isFreePlayingTurnsAdded;
    mapping(uint256 => uint256) public tokenLastUseTimestamp;

    uint256 public xDracePercent;

    event TokenDeposit(address depositor, uint256 tokenId, uint256 timestamp);
    event TokenWithdraw(address withdrawer, uint256 tokenId, uint256 timestamp);
    event GameStart(
        address player,
        bytes tokenIds,
        uint256 timestamp,
        uint256 playerGameCount,
        uint256 globalGameCount
    );

    event TurnBuying(
        address payer,
        uint256 tokenId,
        uint256 price,
        uint256 timestamp
    );
    event RewardDistribution(
        address player,
        uint256 draceReward,
        uint256 xdraceReward,
        uint256 timestamp
    );

    function initialize(
        address _drace,
        address _draceNFT,
        address _approver,
        address _tokenVesting,
        address _xdrace,
        address _feeTo,
        address _xDraceVesting
    ) external initializer {
        __Ownable_init();
        __Context_init();

        xDracePercent = 70;

        drace = IERC20(_drace);
        draceNFT = IDeathRoadNFT(_draceNFT);
        tokenVesting = ITokenVesting(_tokenVesting);
        xdrace = IERC20(_xdrace);
        feeTo = _feeTo;
        if (_approver != address(0)) {
            mappingApprover[_approver] = true;
        }
        xDraceVesting = IxDraceDistributor(_xDraceVesting);
    }

    function setTokenVesting(address _vesting) external onlyOwner {
        tokenVesting = ITokenVesting(_vesting);
    }

    function setXDraceVesting(address _vesting) external onlyOwner {
        xDraceVesting = IxDraceDistributor(_vesting);
    }

    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    function setXDracePercent(uint256 _p) external onlyOwner {
        xDracePercent = _p;
    }

    function addApprover(address _approver, bool _val) public onlyOwner {
        mappingApprover[_approver] = _val;
    }

    function depositNFTsToPlay(
        uint256[] memory _tokenIds,
        uint256[] memory _freeTurns,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        bytes32 message = keccak256(
            abi.encode(msg.sender, _tokenIds, _freeTurns, _expiryTime)
        );
        require(
            verifySigner(message, r, s, v),
            "depositNFTsToPlay::invalid operator"
        );

        require(
            _tokenIds.length == _freeTurns.length,
            "depositNFTsToPlay: Invalid input length"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            draceNFT.transferFrom(msg.sender, address(this), _tokenIds[i]);
            tokenDeposits[_tokenIds[i]].depositor = msg.sender;
            tokenDeposits[_tokenIds[i]].timestamp = block.timestamp;
            tokenDeposits[_tokenIds[i]].tokenId = _tokenIds[i];
            depositTokenList[msg.sender].push(_tokenIds[i]);
            _checkOrAddFreePlayingTurns(_tokenIds[i], _freeTurns[i]);
            emit TokenDeposit(msg.sender, _tokenIds[i], block.timestamp);
        }
    }

    function _checkOrAddFreePlayingTurns(uint256 _tokenId, uint256 _freeTurn)
        internal
    {
        if (!isFreePlayingTurnsAdded[_tokenId]) {
            isFreePlayingTurnsAdded[_tokenId] = true;
            tokenPlayingTurns[_tokenId] = tokenPlayingTurns[_tokenId].add(
                _freeTurn
            );
            require(
                tokenPlayingTurns[_tokenId] > 0,
                "Wait for setting up free turns for the token"
            );
        }
    }

    function distributeRewards(
        address _recipient,
        uint256 _draceAmount,
        uint256 _xdraceAmount,
        uint256 _cumulativeReward,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        //verify signature
        bytes32 message = keccak256(
            abi.encode(
                _recipient,
                _draceAmount,
                _xdraceAmount,
                _cumulativeReward
            )
        );

        require(
            verifySigner(message, r, s, v),
            "distributeRewards::invalid operator"
        );

        _distribute(_recipient, _draceAmount, _xdraceAmount, _cumulativeReward);
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

    function withdrawAllNFTs(
        uint64[] memory _spentPlayTurns,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        bytes32 message = keccak256(
            abi.encode(msg.sender, _spentPlayTurns, _expiryTime)
        );

        require(verifySigner(message, r, s, v), "withdrawAllNFTs: invalid operator");

        uint256[] memory _tokenIds = depositTokenList[msg.sender];
        require(
            _spentPlayTurns.length == _tokenIds.length,
            "invalid playing turns input"
        );

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (tokenDeposits[_tokenIds[i]].depositor == msg.sender) {
                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                if (tokenPlayingTurns[_tokenIds[i]] >= _spentPlayTurns[i]) {
                    tokenPlayingTurns[_tokenIds[i]] = tokenPlayingTurns[
                        _tokenIds[i]
                    ].sub(_spentPlayTurns[i]);
                } else {
                    tokenPlayingTurns[_tokenIds[i]] = 0;
                }
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
            }
        }
        delete depositTokenList[msg.sender];
    }

    function emergencyWithdrawAllNFTs() public {
        uint256[] memory _tokenIds = depositTokenList[msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (tokenDeposits[_tokenIds[i]].depositor == msg.sender) {
                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                tokenPlayingTurns[_tokenIds[i]] = 0;
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
            }
        }
        delete depositTokenList[msg.sender];
    }

    function withdrawNFT(
        uint256 _tokenId,
        uint256 _spentPlayTurn,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(
            tokenDeposits[_tokenId].depositor == msg.sender,
            "withdrawNFT: NFT not yours"
        );

        bytes32 message = keccak256(
            abi.encode(msg.sender, _spentPlayTurn, _expiryTime)
        );

        require(verifySigner(message, r, s, v), "withdrawNFT: invalid operator");

        uint256[] memory _tokenIds = depositTokenList[msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_tokenId == _tokenIds[i]) {
                if (tokenPlayingTurns[_tokenId] >= _spentPlayTurn) {
                    tokenPlayingTurns[_tokenId] = tokenPlayingTurns[_tokenId]
                        .sub(_spentPlayTurn);
                } else {
                    tokenPlayingTurns[_tokenId] = 0;
                }

                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
                depositTokenList[msg.sender][i] = depositTokenList[msg.sender][
                    _tokenIds.length - 1
                ];
                depositTokenList[msg.sender].pop();
                return;
            }
        }
    }

    function emergecyWithdrawNFT(uint256 _tokenId) external {
        require(
            tokenDeposits[_tokenId].depositor == msg.sender,
            "withdrawNFT: NFT not yours"
        );

        uint256[] memory _tokenIds = depositTokenList[msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_tokenId == _tokenIds[i]) {
                tokenPlayingTurns[_tokenId] = 0;

                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                delete tokenDeposits[_tokenIds[i]];
                emit TokenWithdraw(msg.sender, _tokenIds[i], block.timestamp);
                depositTokenList[msg.sender][i] = depositTokenList[msg.sender][
                    _tokenIds.length - 1
                ];
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
        uint256 _cumulativeReward
    ) internal {
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

        IMint(address(xdrace)).mint(address(this), _xdraceAmount);
        IERC20(address(xdrace)).approve(address(xDraceVesting), _xdraceAmount);
        xDraceVesting.lock(_recipient, _xdraceAmount);

        emit RewardDistribution(
            _recipient,
            _draceAmount,
            _xdraceAmount,
            block.timestamp
        );
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
        bytes32 message = keccak256(
            abi.encode(
                "buyPlayingTurn",
                _tokenId,
                _price,
                _turnCount,
                _usexDrace,
                _expiry
            )
        );
        address signer = recoverSigner(r, s, v, message);
        require(mappingApprover[signer], "buyPlayingTurn::invalid operator");

        _buyPlayingTurn(_tokenId, _price, _turnCount, _usexDrace);
    }

    function _buyPlayingTurn(
        uint256 _tokenId,
        uint256 _price, //price per turn
        uint256 _turnCount,
        bool _usexDrace
    ) internal {
        require(
            isFreePlayingTurnsAdded[_tokenId],
            "Token was never deposited in the contract"
        );
        uint256 _totalFee = _turnCount * _price;
        if (_usexDrace) {
            uint256 xDraceNeeded = _totalFee.mul(xDracePercent).div(100);

            drace.safeTransferFrom(
                msg.sender,
                feeTo,
                _totalFee.sub(xDraceNeeded)
            );
            ERC20Burnable(address(xdrace)).burnFrom(msg.sender, xDraceNeeded); //burn xDrace immediately
        } else {
            drace.safeTransferFrom(msg.sender, feeTo, _totalFee);
        }

        tokenPlayingTurns[_tokenId] = tokenPlayingTurns[_tokenId].add(
            _turnCount
        );
        //reset timestamp
        tokenLastUseTimestamp[_tokenId] = 0;
        emit TurnBuying(msg.sender, _tokenId, _price, block.timestamp);
    }

    function getDepositTokenList(address _addr)
        external
        view
        returns (uint256[] memory)
    {
        return depositTokenList[_addr];
    }

    function getGameTokenInfo(uint64[] calldata _tokenIds)
        external
        view
        returns (uint256[] memory turns, uint256[] memory lastUsed)
    {
        turns = new uint256[](_tokenIds.length);
        lastUsed = new uint256[](_tokenIds.length);
        uint256 len = _tokenIds.length;
        for (uint256 i = 0; i < len; i++) {
            turns[i] = tokenPlayingTurns[_tokenIds[i]];
            lastUsed[i] = tokenLastUseTimestamp[_tokenIds[i]];
        }
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
