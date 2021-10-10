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

contract GameControlV3 is
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

    struct UserInfo {
        uint256[] depositTokenList;
        uint256 xdraceDeposited;
        uint256 draceDeposited;
    }

    address public feeTo;

    IDeathRoadNFT public draceNFT;
    IERC20 public drace;
    IERC20 public xdrace;
    mapping(uint256 => DepositInfo) public tokenDeposits;

    //approvers will verify whether:
    //1. Game is in maintenance or not
    //2. Users are using at least one car and one gun in the token id list
    mapping(address => bool) public mappingApprover;
    ITokenVesting public tokenVesting;
    IxDraceDistributor public xDraceVesting;

    mapping(uint256 => uint256) public tokenPlayingTurns;
    mapping(uint256 => bool) public isFreePlayingTurnsAdded;
    mapping(uint256 => uint256) public tokenLastUseTimestamp;
    mapping(address => UserInfo) public userInfo;
    mapping(bytes32 => bool) public withdrawIdSet;

    uint256 public xDracePercent;
    bool public allowEmergencyWithdrawNFT;

    event NFTDeposit(address depositor, uint256 tokenId, uint256 timestamp);
    event NFTWithdraw(
        bytes32 withdrawId,
        address withdrawer,
        bytes tokenIds,
        bytes spentTurns,
        uint256 timestamp
    );

    event DraceDeposit(
        address depositor,
        uint256 draceAmount,
        uint256 xdraceAmount,
        uint256 timestamp
    );
    event DraceWithdraw(
        bytes32 withdrawId,
        address withdrawer,
        uint256 draceAmount,
        uint256 xdraceAmount,
        uint256 timestamp
    );

    event TurnBuying(
        address payer,
        uint256 tokenId,
        uint256 price,
        uint256 timestamp
    );
    event RewardDistribution(
        bytes32 withdrawId,
        address player,
        uint256 draceReward,
        uint256 xdraceReward,
        uint256 timestamp
    );

    modifier notWithdrawYet(bytes32 _withdrawId) {
        require(!withdrawIdSet[_withdrawId], "Already withdraw");
        _;
    }

    modifier timeNotExpired(uint256 _expiryTime) {
        require(_expiryTime >= block.timestamp, "Time expired");
        _;
    }

    modifier onlyAllowEmergencyWithdraw() {
        require(allowEmergencyWithdrawNFT, "not allowed emergency withdraw");
        _;
    }

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

    function setAllowEmergencyWithdrawNFT(bool _val) external onlyOwner {
        allowEmergencyWithdrawNFT = _val;
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
        uint64[] memory _freeTurns,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external timeNotExpired(_expiryTime) {
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

        _depositNFTsToPlay(_tokenIds, _freeTurns);
    }

    function _depositNFTsToPlay(
        uint256[] memory _tokenIds,
        uint64[] memory _freeTurns
    ) internal {
        UserInfo storage _userInfo = userInfo[msg.sender];
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            draceNFT.transferFrom(msg.sender, address(this), _tokenIds[i]);
            tokenDeposits[_tokenIds[i]].depositor = msg.sender;
            tokenDeposits[_tokenIds[i]].timestamp = block.timestamp;
            tokenDeposits[_tokenIds[i]].tokenId = _tokenIds[i];
            _userInfo.depositTokenList.push(_tokenIds[i]);
            _checkOrAddFreePlayingTurns(_tokenIds[i], _freeTurns[i]);
            emit NFTDeposit(msg.sender, _tokenIds[i], block.timestamp);
        }
    }

    function depositTokens(uint256 _draceAmount, uint256 _xdraceAmount)
        external
    {
        drace.safeTransferFrom(msg.sender, address(this), _draceAmount);
        xdrace.safeTransferFrom(msg.sender, address(this), _xdraceAmount);

        UserInfo storage _userInfo = userInfo[msg.sender];
        _userInfo.draceDeposited = _userInfo.draceDeposited + _draceAmount;
        _userInfo.xdraceDeposited = _userInfo.xdraceDeposited + _xdraceAmount;

        emit DraceDeposit(
            msg.sender,
            _draceAmount,
            _xdraceAmount,
            block.timestamp
        );
    }

    function withdrawTokens(
        uint256 _pendingToSpendDrace,
        uint256 _pendingToSpendxDrace,
        uint256 _expiryTime,
        bytes32 _withdrawId,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external notWithdrawYet(_withdrawId) timeNotExpired(_expiryTime) {
        bytes32 message = keccak256(
            abi.encode(
                msg.sender,
                _pendingToSpendDrace,
                _pendingToSpendxDrace,
                _withdrawId,
                _expiryTime
            )
        );

        require(
            verifySigner(message, r, s, v),
            "distributeRewards::invalid operator"
        );

        _withdrawTokens(
            _pendingToSpendDrace,
            _pendingToSpendxDrace,
            _withdrawId
        );
    }

    function _withdrawTokens(
        uint256 _pendingToSpendDrace,
        uint256 _pendingToSpendxDrace,
        bytes32 _withdrawId
    ) internal {
        withdrawIdSet[_withdrawId] = true;

        UserInfo storage _userInfo = userInfo[msg.sender];
        if (_userInfo.draceDeposited >= _pendingToSpendDrace) {
            drace.safeTransfer(
                msg.sender,
                _userInfo.draceDeposited.sub(_pendingToSpendDrace)
            );
            //burn the pending
            ERC20Burnable(address(drace)).burn(_pendingToSpendDrace);
        } else {
            ERC20Burnable(address(drace)).burn(_userInfo.draceDeposited);
        }

        if (_userInfo.xdraceDeposited >= _pendingToSpendxDrace) {
            xdrace.safeTransfer(
                msg.sender,
                _userInfo.xdraceDeposited.sub(_pendingToSpendxDrace)
            );
            ERC20Burnable(address(xdrace)).burn(_pendingToSpendxDrace);
        } else {
            ERC20Burnable(address(xdrace)).burn(_userInfo.xdraceDeposited);
        }

        _userInfo.draceDeposited = 0;
        _userInfo.xdraceDeposited = 0;

        emit DraceWithdraw(
            _withdrawId,
            msg.sender,
            _pendingToSpendDrace,
            _pendingToSpendxDrace,
            block.timestamp
        );
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
        bytes32 _withdrawId,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external notWithdrawYet(_withdrawId) timeNotExpired(_expiryTime) {
        //verify signature
        bytes32 message = keccak256(
            abi.encode(
                _recipient,
                _draceAmount,
                _xdraceAmount,
                _withdrawId,
                _expiryTime
            )
        );

        require(
            verifySigner(message, r, s, v),
            "distributeRewards::invalid operator"
        );

        _distribute(_recipient, _draceAmount, _xdraceAmount, _withdrawId);
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
        bytes32 _withdrawId,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public notWithdrawYet(_withdrawId) timeNotExpired(_expiryTime) {
        UserInfo storage _userInfo = userInfo[msg.sender];
        bytes32 message = keccak256(
            abi.encode(
                msg.sender,
                _userInfo.depositTokenList,
                _spentPlayTurns,
                _withdrawId,
                _expiryTime
            )
        );

        require(
            verifySigner(message, r, s, v),
            "withdrawAllNFTs: invalid operator"
        );

        _withdrawAllNFTs(_spentPlayTurns, _withdrawId);
    }

    function _withdrawAllNFTs(
        uint64[] memory _spentPlayTurns,
        bytes32 _withdrawId
    ) internal {
        withdrawIdSet[_withdrawId] = true;

        UserInfo storage _userInfo = userInfo[msg.sender];
        uint256[] memory _tokenIds = _userInfo.depositTokenList;
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
            }
        }
        delete _userInfo.depositTokenList;
        emit NFTWithdraw(
            _withdrawId,
            msg.sender,
            abi.encode(_tokenIds),
            abi.encode(_spentPlayTurns),
            block.timestamp
        );
    }

    function emergencyWithdrawAllNFTs() public onlyAllowEmergencyWithdraw {
        UserInfo storage _userInfo = userInfo[msg.sender];
        uint256[] memory _tokenIds = _userInfo.depositTokenList;
        uint64[] memory _tempSpentTurns = new uint64[](_tokenIds.length);
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (tokenDeposits[_tokenIds[i]].depositor == msg.sender) {
                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                _tempSpentTurns[i] = uint64(tokenPlayingTurns[_tokenIds[i]]);
                tokenPlayingTurns[_tokenIds[i]] = 0;
                delete tokenDeposits[_tokenIds[i]];
            }
        }
        delete _userInfo.depositTokenList;

        emit NFTWithdraw(
            bytes32(0),
            msg.sender,
            abi.encode(_tokenIds),
            abi.encode(_tempSpentTurns),
            block.timestamp
        );
    }

    function withdrawNFT(
        uint256 _tokenId,
        uint64 _spentPlayTurn,
        bytes32 _withdrawId,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external notWithdrawYet(_withdrawId) timeNotExpired(_expiryTime) {
        require(
            tokenDeposits[_tokenId].depositor == msg.sender,
            "withdrawNFT: NFT not yours"
        );

        bytes32 message = keccak256(
            abi.encode(
                msg.sender,
                _tokenId,
                _spentPlayTurn,
                _withdrawId,
                _expiryTime
            )
        );

        require(
            verifySigner(message, r, s, v),
            "withdrawNFT: invalid operator"
        );

        _withdrawNFT(_tokenId, _spentPlayTurn, _withdrawId);
    }

    function _withdrawNFT(
        uint256 _tokenId,
        uint64 _spentPlayTurn,
        bytes32 _withdrawId
    ) internal {
        withdrawIdSet[_withdrawId] = true;
        UserInfo storage _userInfo = userInfo[msg.sender];

        uint256[] memory _tokenIds = _userInfo.depositTokenList;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_tokenId == _tokenIds[i]) {
                if (tokenPlayingTurns[_tokenId] >= _spentPlayTurn) {
                    tokenPlayingTurns[_tokenId] =
                        tokenPlayingTurns[_tokenId] -
                        _spentPlayTurn;
                } else {
                    tokenPlayingTurns[_tokenId] = 0;
                }

                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                delete tokenDeposits[_tokenIds[i]];

                uint256[] memory tempTokenIds = new uint256[](1);
                tempTokenIds[0] = _tokenIds[i];
                uint64[] memory tempSpentTurns = new uint64[](1);
                tempSpentTurns[0] = uint64(_spentPlayTurn);

                emit NFTWithdraw(
                    _withdrawId,
                    msg.sender,
                    abi.encode(tempTokenIds),
                    abi.encode(tempSpentTurns),
                    block.timestamp
                );
                _userInfo.depositTokenList[i] = _userInfo.depositTokenList[
                    _tokenIds.length - 1
                ];
                _userInfo.depositTokenList.pop();
                return;
            }
        }
    }

    function emergencyWithdrawNFT(uint256 _tokenId)
        external
        onlyAllowEmergencyWithdraw
    {
        require(
            tokenDeposits[_tokenId].depositor == msg.sender,
            "withdrawNFT: NFT not yours"
        );
        UserInfo storage _userInfo = userInfo[msg.sender];
        uint256[] memory _tokenIds = _userInfo.depositTokenList;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            if (_tokenId == _tokenIds[i]) {
                uint256[] memory tempTokenIds = new uint256[](1);
                tempTokenIds[0] = _tokenIds[i];
                uint64[] memory tempSpentTurns = new uint64[](1);
                tempSpentTurns[0] = uint64(tokenPlayingTurns[_tokenId]);

                emit NFTWithdraw(
                    bytes32(0),
                    msg.sender,
                    abi.encode(tempTokenIds),
                    abi.encode(tempSpentTurns),
                    block.timestamp
                );

                tokenPlayingTurns[_tokenId] = 0;

                draceNFT.transferFrom(address(this), msg.sender, _tokenIds[i]);
                delete tokenDeposits[_tokenIds[i]];
                _userInfo.depositTokenList[i] = _userInfo.depositTokenList[
                    _tokenIds.length - 1
                ];
                _userInfo.depositTokenList.pop();
                return;
            }
        }
    }

    //to save gas, we allow to claim rewards fro a range of game ids
    function _distribute(
        address _recipient,
        uint256 _draceAmount,
        uint256 _xdraceAmount,
        bytes32 _withdrawId
    ) internal {
        withdrawIdSet[_withdrawId] = true;
        //distribute rewards
        //xDRACE% released immediately, drace vested
        drace.safeApprove(address(tokenVesting), _draceAmount);
        tokenVesting.lock(_recipient, _draceAmount);

        IMint(address(xdrace)).mint(address(this), _xdraceAmount);
        IERC20(address(xdrace)).approve(address(xDraceVesting), _xdraceAmount);
        xDraceVesting.lock(_recipient, _xdraceAmount);

        emit RewardDistribution(
            _withdrawId,
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
    ) external timeNotExpired(_expiry) {
        bytes32 message = keccak256(
            abi.encode(
                msg.sender,
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
        return userInfo[_addr].depositTokenList;
    }

    function getUserInfo(address _addr)
        external
        view
        returns (
            uint256[] memory depositTokenList,
            uint256 xDraceDeposited,
            uint256 draceDeposited
        )
    {
        UserInfo memory info = userInfo[_addr];
        return (
            info.depositTokenList,
            info.xdraceDeposited,
            info.draceDeposited
        );
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
