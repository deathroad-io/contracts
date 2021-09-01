pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../lib/BlackholePrevention.sol";
import "../interfaces/IPancakeRouter02.sol";

contract FeeDistribution is Ownable, Initializable, BlackholePrevention {
    using SafeMath for uint256;

    ERC20Burnable public drace;

    struct Distribution {
        address receiver;
        uint256 percentX10;
    }

    Distribution[] public distributions;
    IPancakeRouter02 public routerV2;
    address public liquidityReceiver;

    function initialize(
        address _drace,
        address[] memory _tokenReceivers,
        uint256[] memory _percents
    ) external initializer {
        drace = ERC20Burnable(_drace);
        _setDistributions(_tokenReceivers, _percents);
    }

    function setLiquidityReceiver(address _addr) external onlyOwner {
        liquidityReceiver = _addr;
    }
    function setRouter(address _router) external onlyOwner {
        routerV2 = IPancakeRouter02(_router);
    }

    function setDistributions(
        address[] memory _tokenReceivers,
        uint256[] memory _percents
    ) external onlyOwner {
        _setDistributions(_tokenReceivers, _percents);
    }

    function _setDistributions(
        address[] memory _tokenReceivers,
        uint256[] memory _percents
    ) internal {
        require(
            _tokenReceivers.length == _percents.length,
            "invalid distribution input"
        );
        delete distributions;
        uint256 totalPercent = 0;
        for (uint256 i = 0; i < _tokenReceivers.length; i++) {
            distributions.push(Distribution(_tokenReceivers[i], _percents[i]));
            totalPercent = totalPercent.add(_percents[i]);
        }
        require(totalPercent <= 1000, "percentage too high");
    }

    function distribute() external onlyOwner {
        uint256 length = distributions.length;
        uint256 balance = drace.balanceOf(address(this));
        for (uint256 i = 0; i < length; i++) {
            Distribution storage d = distributions[i];
            if (d.receiver == address(0)) {
                //burn
                drace.burn(balance.mul(d.percentX10).div(1000));
            } else {
                drace.transfer(d.receiver, balance.mul(d.percentX10).div(1000));
            }
        }

        //add the rest to liquidity
        uint256 rest = drace.balanceOf(address(this));
        if (address(routerV2) != address(0)) {
            //sell half and add liquidity
            uint256 half = rest.div(2);
            drace.approve(address(routerV2), half);

            address[] memory path = new address[](2);
            path[0] = address(drace);
            path[1] = routerV2.WETH();
            IWETH weth = IWETH(routerV2.WETH());

            routerV2.swapExactTokensForTokens(
                half,
                0,
                path,
                address(this),
                block.timestamp + 100
            );

            rest = drace.balanceOf(address(this));
            uint256 wethBalance = weth.balanceOf(address(this));

            drace.approve(address(routerV2), rest);
            weth.approve(address(routerV2), wethBalance);

            address receiver = liquidityReceiver == address(0)? owner() : liquidityReceiver;
            routerV2.addLiquidity(address(drace), address(weth), rest, wethBalance, 0, 0, receiver, block.timestamp + 100);
        }
    }

    function withdrawEther(address payable receiver, uint256 amount)
        external
        virtual
        onlyOwner
    {
        _withdrawEther(receiver, amount);
    }

    function withdrawERC20(
        address payable receiver,
        address tokenAddress,
        uint256 amount
    ) external virtual onlyOwner {
        _withdrawERC20(receiver, tokenAddress, amount);
    }

    function withdrawERC721(
        address payable receiver,
        address tokenAddress,
        uint256 tokenId
    ) external virtual onlyOwner {
        _withdrawERC721(receiver, tokenAddress, tokenId);
    }
}
