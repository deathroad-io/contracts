pragma solidity ^0.8.0;
import "../farming/MasterChef.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MasterChefMock is MasterChef {
    using SafeMath for uint256;
    function depositNFTMock(
        uint256 _tokenId,
        uint256 _dracePoint
    ) public {
        require(nftPoolId != type(uint256).max, "NFT Pool not exist");

        PoolInfo storage pool = poolInfo[nftPoolId];
        UserInfo storage user = userInfo[nftPoolId][msg.sender];
        updatePool(nftPoolId);

        if (user.nftPoint > 0) {
            uint256 pending = user
                .nftPoint
                .mul(pool.accDRACEPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            addRecordedReward(msg.sender, pending);
        }
        nft.transferFrom(msg.sender, address(this), _tokenId);
        user.stakedNFTs.push(_tokenId);
        user.nftPoint = user.nftPoint.add(_dracePoint);
        user.rewardDebt = user.nftPoint.mul(pool.accDRACEPerShare).div(1e12);
        pool.totalNFTPoint = pool.totalNFTPoint.add(_dracePoint);
        user.nftDepositPoint[_tokenId] = _dracePoint;
        user.lastNFTDepositTimestamp = block.timestamp;

        emit NFTDeposit(msg.sender, nftPoolId, _tokenId, _dracePoint);
    }
}