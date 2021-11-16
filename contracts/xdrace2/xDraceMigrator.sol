pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../interfaces/IMint.sol";
contract xDraceMigrator is Ownable, Pausable, Initializable {
    
    IERC20 public oldXDrace;
    IMint public xDrace2;

    function initialize(address _old, address _new) external initializer {
        oldXDrace = IERC20(_old);
        xDrace2 = IMint(_new);
    }

    function migrate() external whenNotPaused {
        uint256 bal = oldXDrace.balanceOf(msg.sender);
        ERC20Burnable(address(oldXDrace)).burnFrom(msg.sender, bal);
        xDrace2.mint(msg.sender, bal);
    }

    function setPause(bool _val) external onlyOwner {
        if (_val) {
            _pause();
        } else {
            _unpause();
        }
    }
}