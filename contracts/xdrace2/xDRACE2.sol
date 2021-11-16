pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../lib/TokenBurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/ILiquidityAdder.sol";
import "../lib/BlackholePrevention.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

contract xDRACE2 is
    Initializable,
    TokenBurnableUpgradeable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    BlackholePrevention
{
    ILiquidityAdder public liquidityAdder;
    mapping(address => bool) public pancakePairs;
    mapping(address => bool) public minters;
   
    function initialize(
        address _liquidityHolder
    ) public initializer {
        __ERC20_init("DeathRoad xDRACEV2", "xDRACE");
        __Ownable_init();

        liquidityAdder = ILiquidityAdder(_liquidityHolder);
    }

    function setMinters(address[] memory _minters, bool val) external onlyOwner {
        for(uint256 i = 0; i < _minters.length; i++) {
            minters[_minters[i]] = val;
        }
    }

    function mint(address _to, uint256 _amount) external {
        require(minters[msg.sender], "Not minter");
        _mint(_to, _amount);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setLiquidityHolding(address _liquidityAdder)
        external
        onlyOwner
    {
        liquidityAdder = ILiquidityAdder(_liquidityAdder);
    }

    function setPancakePairs(address[] memory _pancakePairs, bool val)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _pancakePairs.length; i++) {
            pancakePairs[_pancakePairs[i]] = val;
        }
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        if (!pancakePairs[sender] && address(liquidityAdder) != address(0)) {
            liquidityAdder.addLiquidity();
        }

        unchecked {
            _balances[sender] = senderBalance - amount;
        }

        if (
            address(liquidityAdder) != address(0) &&
            sender != address(liquidityAdder) &&
            recipient != address(liquidityAdder)
        ) {
            (
                uint256 liquidityFee,
                uint256 burnFee
            ) = liquidityAdder.getTransferFees(sender, recipient, amount);
            uint256 burnAmount = (amount * burnFee) / 10000;
            uint256 liquidityHolderAmount = (amount * liquidityFee) / 10000;
            //burn
            _totalSupply -= burnAmount;
            //liquidityFee
            _balances[address(liquidityAdder)] += liquidityHolderAmount;

            _balances[recipient] += amount - burnAmount - liquidityHolderAmount;
           
            emit Transfer(sender, address(0), burnAmount);
            emit Transfer(sender, address(liquidityAdder), liquidityHolderAmount);
            emit Transfer(sender, recipient, amount - burnAmount - liquidityHolderAmount);
        } else {
            _balances[recipient] += amount;
             emit Transfer(sender, recipient, amount);
        }
         _afterTokenTransfer(sender, recipient, amount);
    }

    //rescue loss token
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
