pragma solidity ^0.8.0;

interface ITokenLock {
    function unlock(address _addr, uint256 _index) external;

    function lock(
        address _token,
        address _addr,
        uint256 _amount,
        uint256 _lockedTime
    ) external;

    function getLockInfo(address _user)
        external
        view
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        );

    function getLockInfoByIndexes(address _addr, uint256[] memory _indexes)
        external
        view
        returns (
            bool[] memory isWithdrawns,
            address[] memory tokens,
            uint256[] memory unlockableAts,
            uint256[] memory amounts
        );

    function getLockInfoLength(address _addr) external view returns (uint256);
}
