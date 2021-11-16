pragma solidity ^0.8.2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IPancakePair.sol";
import "../interfaces/IPancakeRouter02.sol";
import "../interfaces/ILiquidityAdder.sol";
import "../lib/BlackholePrevention.sol";

contract LiquidityAdding is
    Ownable,
    Initializable,
    ILiquidityAdder,
    BlackholePrevention
{
    using SafeERC20 for IERC20;
    IERC20 public xdraceV2;
    bool public swapAndLiquidifyEnabled;
    bool public inSwapAndLiquify;
    IPancakePair public liquidityPair;
    IPancakeRouter02 public pancakeRouter;
    mapping(address => bool) public liquidityCallers;
    uint256 public minimumToAddLiquidity;

    mapping(address => bool) public whitelist;

    event Whitelist(address _addr, bool val);
    uint256 public liquidityFee;
    uint256 public burnFee;

    constructor() {
        whitelist[msg.sender] = true;
        liquidityFee = 400;
        burnFee = 200;
    }

    function initialize(address _xdraceV2, address _pancakeRouter)
        external
        initializer
    {
        xdraceV2 = IERC20(_xdraceV2);
        liquidityCallers[_xdraceV2] = true;
        minimumToAddLiquidity = 200e18;

        swapAndLiquidifyEnabled = true;
        inSwapAndLiquify = false;
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
    }

    function setxDrace(address _xdraceV2) external onlyOwner {
        xdraceV2 = IERC20(_xdraceV2);
        liquidityCallers[_xdraceV2] = true;
    }

    function addLiquidity() external override {
        require(liquidityCallers[msg.sender], "not liquidity caller");
        if (
            swapAndLiquidifyEnabled &&
            !inSwapAndLiquify &&
            address(liquidityPair) != address(0)
        ) {
            if (xdraceV2.balanceOf(address(this)) >= minimumToAddLiquidity) {
                swapAndLiquidify(minimumToAddLiquidity);
            }
        }
    }

    function setMinimumToAddLiquidity(uint256 _minimumToAddLiquidity)
        external
        onlyOwner
    {
        minimumToAddLiquidity = _minimumToAddLiquidity;
    }

    function setPancakeRouter(address _pancakeRouter) external onlyOwner {
        pancakeRouter = IPancakeRouter02(_pancakeRouter);
    }

    function setSwapAndLiquidifyEnabled(bool _swapAndLiquidifyEnabled)
        external
        onlyOwner
    {
        swapAndLiquidifyEnabled = _swapAndLiquidifyEnabled;
    }

    function setLiquidityPair(address _liquidityPair) external onlyOwner {
        liquidityPair = IPancakePair(_liquidityPair);
        if (_liquidityPair != address(0)) {
            require(
                liquidityPair.token0() == address(xdraceV2) ||    
                    liquidityPair.token1() == address(xdraceV2),   
                "One of paired tokens must be xdraceV2"
            );
        }
    }

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function swapAndLiquidify(uint256 _amount) internal lockTheSwap {
        // split the contract balance into halves
        uint256 half = _amount / 2;
        uint256 otherHalf = _amount - half;

        // swap tokens
        swapTokensForToken(half);

        // add liquidity to pancake
        addLiquidityInternal(otherHalf);
    }

    function swapTokensForToken(uint256 tokenAmount) private {
        // generate the pancake pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(xdraceV2);    //
        path[1] = liquidityPair.token0() == address(xdraceV2)   // huong
            ? liquidityPair.token1()
            : liquidityPair.token0();

        xdraceV2.approve(address(pancakeRouter), tokenAmount);

        // make the swap
        pancakeRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of other token
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidityInternal(uint256 tokenAmount) private {
        address otherToken = liquidityPair.token0() == address(xdraceV2) // huong 
            ? liquidityPair.token1()
            : liquidityPair.token0();
        uint256 otherTokenAmount = IERC20(otherToken).balanceOf(address(this));
        IERC20(otherToken).approve(
            address(pancakeRouter),
            otherTokenAmount
        );
        // approve token transfer to cover all possible scenarios
        xdraceV2.approve(address(pancakeRouter), tokenAmount);

        // add the liquidity
        pancakeRouter.addLiquidity(
            address(xdraceV2),   //huong
            otherToken,
            tokenAmount,
            otherTokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function setWhitelist(address[] memory _addrs, bool _val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            whitelist[_addrs[i]] = _val;
            emit Whitelist(_addrs[i], _val);
        }
    }

    function setFees(
        uint256 _liquidityFee,
        uint256 _burnFee
    ) external onlyOwner {
        liquidityFee = _liquidityFee;
        burnFee = _burnFee;
    }

    function getTransferFees(
        address sender,
        address recipient,
        uint256 amount
    )
        external
        view
        override
        returns (
            uint256 _liquidityFee,
            uint256 _burnFee
        )
    {
        if (whitelist[sender] || whitelist[recipient]) return (0, 0);
        return (liquidityFee, burnFee); 
    }

    //rescue token
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
