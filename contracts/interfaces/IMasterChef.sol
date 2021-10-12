pragma solidity ^0.8.0;

interface IMasterChef {
    function getUserInfo(uint256 _pid, address _user)
        external
        view
        returns (
            uint256 amount, // How many LP tokens the user has provided.
            uint256 rewardDebt, // Reward debt. See explanation below.
            uint256 nftPoint,
            uint256[] memory stakedNFTs,
            uint256 lastNFTDepositTimestamp
        );
}
