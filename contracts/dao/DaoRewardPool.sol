pragma solidity ^0.8.0;

import "../interfaces/IDaoRewardPool.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract DaoRewardPool is IDaoRewardPool, Ownable, Initializable {
    using SafeERC20 for IERC20;
    IERC20 public drace;
    mapping(address => bool) public authorizeds;

    event SetAuthorized(address _aut, bool _val);
    event TransferReward(address _recipient, uint256 _amount);

    function initialize(address _drace) external initializer {
        drace = IERC20(_drace);
    }

    function SetAuthorizeds(address _auth, bool _val) external onlyOwner {
        authorizeds[_auth] = _val;
        emit SetAuthorized(_auth, _val);
    }

    function transferReward(address recipient, uint256 amount)
        external
        override
    {
        require(authorizeds[msg.sender], "!not authorized");
        drace.safeTransfer(recipient, amount);
        emit TransferReward(recipient, amount);
    }
}
