pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSender {
    function sendToMany(address token, address[] memory addrs, uint256 amount) external {
        for(uint256 i = 0; i < addrs.length; i++) {
            IERC20(token).transferFrom(msg.sender, addrs[i], amount);
        }
    }
}