pragma solidity ^0.8.0;
import "./BlackholePreventionOwnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/IPancakePair.sol";

contract LiquidityAdder is BlackholePreventionOwnable, Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;

    IERC20 public drace;
    IPancakePair public pancakePair;
    uint256 public liquidityAddAmount = 1000e18;
    uint256 public liquidityPeriod = 12 hours;
    uint256 public lastUpdated;
    bool public allowAnyOneToCall = false;
    address public otherTokenAddress;
    IPancakeRouter02 public routerV2;
    address public liquidityReceiver;
    mapping(address => bool) public whitelistedContracts;

    function initialize(address _drace, address _pair) external initializer {
        drace = IERC20(_drace);
        pancakePair = IPancakePair(_pair);
        liquidityReceiver = owner();

        otherTokenAddress = pancakePair.token0() == address(drace)
            ? pancakePair.token1()
            : pancakePair.token0();
    }

    function setLiquidityReceiver(address _r) external onlyOwner {
        liquidityReceiver = _r;
    }

    function setWhitelistedContract(address _addr, bool val) external onlyOwner {
        whitelistedContracts[_addr] = val;
    }

    function setRouter(address _router) external onlyOwner {
        routerV2 = IPancakeRouter02(_router);
    }

    function changePair(address _pair) external onlyOwner {
        pancakePair = IPancakePair(_pair);

        otherTokenAddress = pancakePair.token0() == address(drace)
            ? pancakePair.token1()
            : pancakePair.token0();
    }

    function changeLiquidityAmount(uint256 _amount) external onlyOwner {
        liquidityAddAmount = _amount;
    }

    function changeLiquidityPeriod(uint256 _liquidityPeriod)
        external
        onlyOwner
    {
        liquidityPeriod = _liquidityPeriod;
    }

    function setAllowAnyOneToCall(bool val) external onlyOwner {
        allowAnyOneToCall = val;
    }

    function addLiquidity() external {
        if (lastUpdated.add(liquidityPeriod) > block.timestamp) return;
        if (address(routerV2) == address(0)) return;
        if (!allowAnyOneToCall) {
            if (msg.sender != owner()) return;
        } else {
            if (msg.sender.isContract()) {
                if (!whitelistedContracts[msg.sender]) return;
            }
        }

        if (drace.balanceOf(address(this)) < liquidityAddAmount) return;

        //sell half and add liquidity
        uint256 half = liquidityAddAmount.div(2);

        drace.approve(address(routerV2), liquidityAddAmount);

        address[] memory path = new address[](2);
        path[0] = address(drace);
        path[1] = otherTokenAddress;
        IERC20 otherToken = IERC20(otherTokenAddress);

        uint256 minToReceive = routerV2.getAmountsOut(half, path)[1];

        routerV2.swapExactTokensForTokens(
            half,
            minToReceive,
            path,
            address(this),
            block.timestamp + 100
        );

        uint256 otherTokenBalance = otherToken.balanceOf(address(this));

        otherToken.approve(address(routerV2), otherTokenBalance);

        address receiver = liquidityReceiver == address(0)
            ? owner()
            : liquidityReceiver;

        routerV2.addLiquidity(
            address(drace),
            otherTokenAddress,
            half,
            otherTokenBalance,
            0,
            0,
            receiver,
            block.timestamp + 100
        );
        lastUpdated = block.timestamp;
    }
}
