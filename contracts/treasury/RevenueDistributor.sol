pragma solidity ^0.8.0;
import "./BlackholePreventionOwnable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract RevenueDistributor is BlackholePreventionOwnable, Initializable {
    using SafeERC20 for IERC20;

    IERC20 public drace;
    address public foundation;
    address public playToEarnTreasury;
    address public liquidityAdder;

    uint256 public foundationPercent = 25;
    uint256 public playToEarnTreasuryPercent = 35;
    uint256 public liquidityAdderPercent = 25;

    function initialize(address _drace, address _foundation, address _playToEarn, address _liquidityAdder) external initializer {
        drace = IERC20(_drace);
        foundation = _foundation;
        playToEarnTreasury = _playToEarn;
        liquidityAdder = _liquidityAdder;
    }

    function changeFoundation(address _foundation) external onlyOwner {
        foundation = _foundation;
    }

    function changeDrace(address _drace) external onlyOwner {
        drace = IERC20(_drace);
    }

    function changePlayToEarnTreasury(address _playToEarn) external onlyOwner {
        playToEarnTreasury = _playToEarn;
    }

    function changeLiquidityAdder(address _liquidityAdder) external onlyOwner {
        liquidityAdder = _liquidityAdder;
    }

    function changePercents(uint256 _foundationPercent, uint256 _playToEarnTreasuryPercent, uint256 _liquidityAdderPercent) external onlyOwner {
        foundationPercent = _foundationPercent;
        playToEarnTreasuryPercent = _playToEarnTreasuryPercent;
        liquidityAdderPercent = _liquidityAdderPercent;
    }

    function distribute() external onlyOwner {
        uint256 bal = drace.balanceOf(address(this));

        if (bal > 0) {
            uint256 toTransfer = bal * foundationPercent / 100;
            drace.safeTransfer(foundation, toTransfer);

            toTransfer = bal * playToEarnTreasuryPercent / 100;
            drace.safeTransfer(playToEarnTreasury, toTransfer);

            toTransfer = bal * liquidityAdderPercent / 100;
            drace.safeTransfer(liquidityAdder, toTransfer);

            bal = drace.balanceOf(address(this));
            ERC20Burnable(address(drace)).burn(bal);
        }
    }
}