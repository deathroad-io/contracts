pragma solidity ^0.8.0;
import "../interfaces/IMasterChef.sol";
import "../interfaces/IReferralContract.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ReferralContract is Initializable, Ownable, IReferralContract {
    mapping(address => address) public referMap;
    uint256 public minimumStake = 10000e18;
    IMasterChef public masterChef;

    function initialize(address _masterChef) external initializer {
        masterChef = IMasterChef(_masterChef);
    }

    function setMinimumStake(uint256 _minimumStake) external onlyOwner {
        minimumStake = _minimumStake;
    }

    function getReferrer(address _player) external override view returns (address referrer, bool canReceive)  {
        referrer = referMap[_player];
        //get stake
        (uint256 amount,,,,) = masterChef.getUserInfo(1, referrer);
        canReceive = amount >= minimumStake;
    }

    function setReferrer(address _referrer) external {
        require(referMap[msg.sender] == address(0) && _referrer != msg.sender, "Referrer already set or referrer cannot be the same as user");
        referMap[msg.sender] = _referrer;
    }
}