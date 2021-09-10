pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract DLPMock is ERC20Burnable {
    // Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    constructor(address _to) ERC20("DeathRoad LP Token Test", "DLP") {
        _mint(_to, 1000000000e18);
    }
}
