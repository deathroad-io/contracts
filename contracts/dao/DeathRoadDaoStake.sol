// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol"; // OZ contracts v4
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol"; // OZ contracts v4
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "../lib/BlackholePreventionUpgradeable.sol";
import "../interfaces/IDaoRewardPool.sol";
import "../interfaces/INFTStakingPoint.sol";
import "../interfaces/ITokenLock.sol";

contract DeathRoadDaoStake is
    Initializable,
    ContextUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    struct TokenStake {
        uint256 stakedAmount;
        uint256 lockedTill;
    }

    struct NFTStake {
        uint256 tokenId;
        uint256 nftPoint;
        uint256 lockedTill;
    }
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 nftPoint;
        NFTStake[] stakedNFTs;
        TokenStake[] stakedTokens;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20Upgradeable lpToken; // Address of LP token contract., address is 0 if it is NFT pool
        uint256 allocPoint; // How many allocation points assigned to this pool. DRACEPoint to distribute per block.
        uint256 lastRewardBlock; // Last block number that DRACEPoint distribution occurs.
        uint256 accDRACEPerShare; // Accumulated DRACEPoint per share, times 1e12. See below.
        uint256 totalNFTPoint;
    }
    // The DRACE TOKEN!
    IERC20Upgradeable public drace;
    IERC721Upgradeable public nft;
    IDaoRewardPool public rewardPool;
    INFTStakingPoint public nftStakingPointHook;
    uint256 public lockedDuration;
    uint256 public nftLockedDuration;
    uint256 public poolLockedTime;

    // the token rewards container

    // Dev address.
    // Block number when bonus DRACE period ends.
    uint256 public bonusEndBlock;
    // DRACE tokens created per block.
    uint256 public dracePerBlock;
    // Bonus muliplier for early DRACE makers.
    uint256 public constant BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    //IMigratorChef public migrator;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when DRACE mining starts.
    uint256 public startBlock;
    uint256 public nftPoolId = type(uint256).max;
    ITokenLock public tokenLock;
    bool public allowEmergencyWithdraw;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event NFTDeposit(
        address indexed user,
        uint256 indexed pid,
        uint256 tokenId,
        uint256 dracePoint
    );
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawNFT(address indexed user, uint256 indexed pid);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event EmergencyWithdrawNFT(address indexed user, uint256 indexed pid);
    event ClaimRewards(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        address _rewardPool,
        address _draceNFT,
        address _drace,
        address _nftStakingPointHook,
        uint256 _dracePerBlock,
        uint256 _startBlock,
        address _tokenLock
    ) external initializer onlyOwner {
        lockedDuration = 60 days;
        poolLockedTime = 1 days;
        nftLockedDuration = 60 days;

        rewardPool = IDaoRewardPool(_rewardPool);
        nft = IERC721Upgradeable(_draceNFT);
        nftStakingPointHook = INFTStakingPoint(_nftStakingPointHook);
        drace = IERC20Upgradeable(_drace);
        dracePerBlock = _dracePerBlock;
        startBlock = _startBlock > 0 ? _startBlock : block.number;
        bonusEndBlock = startBlock.add(50000);
        tokenLock = ITokenLock(_tokenLock);
        allowEmergencyWithdraw = false;

        //add nft pool
        add(1000, address(0), false);
        //DRACE staking pool
        add(1000, address(drace), false);
    }

    function setAllowEmergencyWithdraw(bool _allowEmergencyWithdraw)
        external
        onlyOwner
    {
        allowEmergencyWithdraw = _allowEmergencyWithdraw;
    }

    function changeTokenLock(address _tokenLock) external onlyOwner {
        tokenLock = ITokenLock(_tokenLock);
    }

    function changePoolLockedTime(uint256 _lockedTime) external onlyOwner {
        poolLockedTime = _lockedTime;
    }

    function isNFTPool(uint256 pid) public view returns (bool) {
        return address(poolInfo[pid].lpToken) == address(0);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function setNFTStakingPointHook(address _nftStakingPointHook)
        external
        onlyOwner
    {
        nftStakingPointHook = INFTStakingPoint(_nftStakingPointHook);
    }

    function setRewardPol(address _rewardPool) external onlyOwner {
        rewardPool = IDaoRewardPool(_rewardPool);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        address _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        if (_lpToken == address(0)) {
            require(nftPoolId == type(uint256).max, "NFT Pool already exist");
            nftPoolId = poolInfo.length;
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: IERC20Upgradeable(_lpToken),
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accDRACEPerShare: 0,
                totalNFTPoint: 0
            })
        );
    }

    function setRewardPerBlock(uint256 _r, bool _withUpdate)
        external
        onlyOwner
    {
        if (_withUpdate) {
            massUpdatePools();
        }
        dracePerBlock = _r;
    }

    // Update the given pool's DRACE allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending DRACE on frontend.
    function pendingDRACE(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDRACEPerShare = pool.accDRACEPerShare;
        uint256 lpSupply = 0;
        if (isNFTPool(_pid)) {
            lpSupply = pool.totalNFTPoint;
        } else {
            lpSupply = pool.lpToken.balanceOf(address(this));
        }
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 draceReward = multiplier
                .mul(dracePerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accDRACEPerShare = accDRACEPerShare.add(
                draceReward.mul(1e12).div(lpSupply)
            );
        }
        uint256 amount = isNFTPool(_pid) ? user.nftPoint : user.amount;
        return amount.mul(accDRACEPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = 0;
        if (!isNFTPool(_pid)) {
            lpSupply = pool.lpToken.balanceOf(address(this));
        } else {
            lpSupply = pool.totalNFTPoint;
        }
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 draceReward = multiplier
            .mul(dracePerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);

        pool.accDRACEPerShare = pool.accDRACEPerShare.add(
            draceReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for DRACE allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        require(!isNFTPool(_pid), "Pool ID must not be NFT pool");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accDRACEPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            payReward(msg.sender, pending);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.stakedTokens.push(
            TokenStake({
                stakedAmount: _amount,
                lockedTill: block.timestamp + lockedDuration
            })
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accDRACEPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function depositNFT(uint256[] memory _tokenIds) public {
        require(nftPoolId != type(uint256).max, "NFT Pool not exist");
        require(_tokenIds.length > 0, "Empty token list");
        PoolInfo storage pool = poolInfo[nftPoolId];
        UserInfo storage user = userInfo[nftPoolId][msg.sender];
        updatePool(nftPoolId);

        if (user.nftPoint > 0) {
            uint256 pending = user
                .nftPoint
                .mul(pool.accDRACEPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            payReward(msg.sender, pending);
        }

        uint256 addedPoint = 0;
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];

            nft.transferFrom(msg.sender, address(this), _tokenId);
            uint256 stakingPoint = nftStakingPointHook.getStakingPoint(
                _tokenId,
                address(nft)
            );
            require(
                stakingPoint > 0,
                "depositNFT:NFT is not allocated for staking point"
            );

            user.stakedNFTs.push(
                NFTStake({
                    tokenId: _tokenId,
                    nftPoint: stakingPoint,
                    lockedTill: block.timestamp + nftLockedDuration
                })
            );

            addedPoint = addedPoint.add(stakingPoint);

            emit NFTDeposit(msg.sender, nftPoolId, _tokenId, stakingPoint);
        }

        user.nftPoint = user.nftPoint.add(addedPoint);
        user.rewardDebt = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12);
        pool.totalNFTPoint = pool.totalNFTPoint.add(addedPoint);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(
        uint256 _pid,
        uint256 _amount,
        uint256 _depositId
    ) public {
        require(!isNFTPool(_pid), "Pool ID must not be NFT pool");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        TokenStake storage _deposit = user.stakedTokens[_depositId];
        require(_deposit.stakedAmount >= _amount, "withdraw: not good");
        require(
            _deposit.lockedTill < block.timestamp,
            "withdraw: not unlock time"
        );

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accDRACEPerShare).div(1e12).sub(
            user.rewardDebt
        );
        payReward(msg.sender, pending);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accDRACEPerShare).div(1e12);
        _deposit.stakedAmount -= _amount;
        if (_deposit.stakedAmount == 0) {
            user.stakedTokens[_depositId] = user.stakedTokens[
                user.stakedTokens.length - 1
            ];
            user.stakedTokens.pop();
        }
        //lock in tokenLock
        pool.lpToken.safeApprove(address(tokenLock), _amount);
        tokenLock.lock(
            address(pool.lpToken),
            msg.sender,
            _amount,
            poolLockedTime
        );

        emit Withdraw(msg.sender, _pid, _amount);
    }

    function claimRewards(uint256 _pid) public {
        require(!isNFTPool(_pid), "claimRewards: must not be NFT pool");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending;
        if (_pid == nftPoolId) {
            pending = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12).sub(
                user.rewardDebt
            );
        } else {
            pending = user.amount.mul(pool.accDRACEPerShare).div(1e12).sub(
                user.rewardDebt
            );
        }

        payReward(msg.sender, pending);
        if (_pid == nftPoolId) {
            user.rewardDebt = user.nftPoint.mul(pool.accDRACEPerShare).div(
                1e12
            );
        } else {
            user.rewardDebt = user.amount.mul(pool.accDRACEPerShare).div(1e12);
        }
        emit ClaimRewards(msg.sender, _pid, pending);
    }

    function claimRewardsNFTPool() external {
        require(nftPoolId != type(uint256).max, "NFT Pool not exist");
        UserInfo storage user = userInfo[nftPoolId][msg.sender];

        uint256 _pid = nftPoolId;
        PoolInfo storage pool = poolInfo[_pid];
        updatePool(nftPoolId);
        uint256 pending;
        pending = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12).sub(
            user.rewardDebt
        );

        payReward(msg.sender, pending);
        user.rewardDebt = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12);
        emit ClaimRewards(msg.sender, _pid, pending);
    }

    //always withdraw all NFTs
    function withdrawNFT() external {
        require(nftPoolId != type(uint256).max, "NFT Pool not exist");
        //checking last timestamp NFT deposited

        PoolInfo storage pool = poolInfo[nftPoolId];
        UserInfo storage user = userInfo[nftPoolId][msg.sender];
        require(user.stakedNFTs.length > 0, "withdrawNFT: no nft");

        updatePool(nftPoolId);
        uint256 pending = user
            .nftPoint
            .mul(pool.accDRACEPerShare)
            .div(1e12)
            .sub(user.rewardDebt);

        //transfer nfts back
        for (uint256 i = 0; i < user.stakedNFTs.length; i++) {
            require(
                user.stakedNFTs[i].lockedTill < block.timestamp,
                "withdrawNFT: not unlock time"
            );
            nft.transferFrom(
                address(this),
                msg.sender,
                user.stakedNFTs[i].tokenId
            );
        }
        delete user.stakedNFTs;

        payReward(msg.sender, pending);
        pool.totalNFTPoint = pool.totalNFTPoint.sub(user.nftPoint);
        user.nftPoint = 0;
        user.rewardDebt = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12);
        emit WithdrawNFT(msg.sender, nftPoolId);
    }

    function withdrawSomeNFTs(uint256[] memory _tokenIds) external {
        require(nftPoolId != type(uint256).max, "NFT Pool not exist");
        //checking last timestamp NFT deposited

        PoolInfo storage pool = poolInfo[nftPoolId];
        UserInfo storage user = userInfo[nftPoolId][msg.sender];
        require(user.stakedNFTs.length > 0, "withdrawNFT: not good");

        updatePool(nftPoolId);
        uint256 pending = user
            .nftPoint
            .mul(pool.accDRACEPerShare)
            .div(1e12)
            .sub(user.rewardDebt);

        uint256 minusNFTPoint = 0;

        //transfer nfts back
        for (uint256 k = 0; k < _tokenIds.length; k++) {
            for (uint256 i = 0; i < user.stakedNFTs.length; i++) {
                require(
                    user.stakedNFTs[i].lockedTill < block.timestamp,
                    "withdrawSomeNFTs: not unlock time"
                );
                if (_tokenIds[k] == user.stakedNFTs[i].tokenId) {
                    nft.transferFrom(address(this), msg.sender, _tokenIds[k]);
                    minusNFTPoint = minusNFTPoint.add(
                        user.stakedNFTs[i].nftPoint
                    );

                    //delete from the stakedNFTs list
                    user.stakedNFTs[i] = user.stakedNFTs[
                        user.stakedNFTs.length - 1
                    ];
                    user.stakedNFTs.pop();
                    break;
                }
            }
        }
        //delete user.stakedNFTs;

        payReward(msg.sender, pending);
        pool.totalNFTPoint = pool.totalNFTPoint.sub(minusNFTPoint);
        user.nftPoint = user.nftPoint.sub(minusNFTPoint);
        user.rewardDebt = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12);
        emit WithdrawNFT(msg.sender, nftPoolId);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        require(allowEmergencyWithdraw, "!allowEmergencyWithdraw");
        require(!isNFTPool(_pid), "Pool ID must not be NFT pool");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function emergencyWithdrawNFT() public {
        require(allowEmergencyWithdraw, "!allowEmergencyWithdraw");
        PoolInfo storage pool = poolInfo[nftPoolId];
        UserInfo storage user = userInfo[nftPoolId][msg.sender];

        for (uint256 i = 0; i < user.stakedNFTs.length; i++) {
            if (nft.ownerOf(user.stakedNFTs[i].tokenId) == address(this)) {
                nft.transferFrom(
                    address(this),
                    msg.sender,
                    user.stakedNFTs[i].tokenId
                );
            }
        }
        delete user.stakedNFTs;
        if (pool.totalNFTPoint >= user.nftPoint) {
            pool.totalNFTPoint = pool.totalNFTPoint.sub(user.nftPoint);
        }
        user.nftPoint = 0;
        emit EmergencyWithdrawNFT(msg.sender, nftPoolId);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe DRACE transfer function, just in case if rounding error causes pool to not have enough DRACE.
    function payReward(address _to, uint256 _amount) internal {
        rewardPool.transferReward(_to, _amount);
    }

    function getUserInfo(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 amount, // How many LP tokens the user has provided.
            uint256 rewardDebt, // Reward debt. See explanation below.
            uint256 nftPoint,
            NFTStake[] memory stakedNFTs,
            TokenStake[] memory stakedTokens
        )
    {
        UserInfo storage user = userInfo[_pid][_user];
        return (
            user.amount,
            user.rewardDebt,
            user.nftPoint,
            user.stakedNFTs,
            user.stakedTokens
        );
    }

    function unlock(address _addr, uint256 index) public {
        tokenLock.unlock(_addr, index);
    }

    function getLockInfo(address _user)
        external
        view
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        )
    {
        return tokenLock.getLockInfo(_user);
    }

    function getLockInfoByIndexes(address _addr, uint256[] memory _indexes)
        external
        view
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        )
    {
        return tokenLock.getLockInfoByIndexes(_addr, _indexes);
    }

    function getLockInfoLength(address _addr) external view returns (uint256) {
        return tokenLock.getLockInfoLength(_addr);
    }
}
