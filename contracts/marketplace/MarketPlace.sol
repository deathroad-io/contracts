pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
contract MarketPlace is Ownable, Initializable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    IERC721 public nft;
    IERC20 public drace;
    uint256 public feePercentX10 = 10;  //default 1%
    address public feeReceiver;

    struct SaleInfo {
        bool isSold;
        bool isActive;  //false mint already cancelled
        address owner;
        uint256 lastUpdated;
        uint256 tokenId;
        uint256 price;
        uint256 saleId;
    }

    SaleInfo[] public saleList;

    event NewTokenSale(address owner, uint256 updatedAt, uint256 tokenId, uint256 price, uint256 saleId);
    event TokenSaleUpdated(address owner, uint256 updatedAt, uint256 tokenId, uint256 price, uint256 saleId);
    event SaleCancelled(address owner, uint256 updatedAt, uint256 tokenId, uint256 price, uint256 saleId);
    event TokenPurchase(address owner, address buyer, uint256 updatedAt, uint256 tokenId, uint256 price, uint256 saleId);
    event FeeTransfer(address owner, address buyer, address feeReceiver, uint256 updatedAt, uint256 tokenId, uint256 fee, uint256 saleId);

    modifier onlySaleOwner(uint256 _saleId) {
        require(msg.sender == saleList[_saleId].owner, "Invalid sale owner");
        _;
    }

    function initialize(address _draceNFT, address _drace, address _feeReceiver) external initializer {
        nft = IERC721(_draceNFT);
        drace = IERC20(_drace);
        feeReceiver = _feeReceiver;
    }

    function changeFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 100, "changeFee: new fee too high"); //max 10%
        feePercentX10 = _newFee;
    }

    function changeFeeReceiver(address _newFeeReceiver) external onlyOwner {
        require(_newFeeReceiver != address(0), "changeFeeReceiver: null address"); //max 10%
        feeReceiver = _newFeeReceiver;
    }

    //_price: in drace token
    //_val: true => open for sale
    //_val: false => cancel sale, return token to owner
    function setTokenSale(uint256 _tokenId, uint256 _price) external {
        require(_price > 0, "price must not be 0");
        //transfer token from sender to contract
        nft.transferFrom(msg.sender, address(this), _tokenId);
        //create a sale
        saleList.push(SaleInfo(
            false,
            true,
            msg.sender,
            block.timestamp,
            _tokenId,
            _price,
            saleList.length
        ));
        emit NewTokenSale(msg.sender, block.timestamp, _tokenId, _price, saleList.length - 1);
    }

    function changeTokenSalePrice(uint256 _saleId, uint256 _newPrice) external onlySaleOwner (_saleId ) {
        require(_newPrice > 0, "price must not be 0");
        SaleInfo storage sale = saleList[_saleId];
        require(sale.isActive && !sale.isSold, "changeTokenSalePrice: sale inactive or already sold");
        sale.price = _newPrice;
        sale.lastUpdated = block.timestamp;

        emit TokenSaleUpdated(msg.sender, block.timestamp, sale.tokenId, _newPrice, _saleId);
    }

    function cancelTokenSale(uint256 _saleId) external onlySaleOwner (_saleId) {
        SaleInfo storage sale = saleList[_saleId];
        require(sale.isActive && !sale.isSold, "cancelTokenSale: sale inactive or already sold");
        sale.isActive = false;
        nft.transferFrom(address(this), msg.sender, sale.tokenId);
        sale.lastUpdated = block.timestamp;

        emit SaleCancelled(msg.sender, block.timestamp, sale.tokenId, sale.price, _saleId);
    }

    function buyToken(uint256 _saleId) external {
        SaleInfo storage sale = saleList[_saleId];
        require(sale.isActive && !sale.isSold, "cancelTokenSale: sale inactive or already sold");

        sale.isSold = true;
        sale.isActive = false;

        uint256 price = sale.price;
        //transfer fee
        drace.safeTransferFrom(msg.sender, feeReceiver, price.mul(feePercentX10).div(1000));
        //transfer to seller
        drace.safeTransferFrom(msg.sender, sale.owner, price.mul(1000 - feePercentX10).div(1000));
        sale.lastUpdated = block.timestamp;

        nft.transferFrom(address(this), msg.sender, sale.tokenId);

        emit TokenPurchase(sale.owner, msg.sender, block.timestamp, sale.tokenId, sale.price, _saleId);
        emit FeeTransfer(sale.owner, msg.sender, feeReceiver, block.timestamp, sale.tokenId, price.mul(feePercentX10).div(1000), _saleId);
    }

    function getAllSales() external view returns (SaleInfo[] memory) {
        return saleList;
    }

    function getActiveSales() external view returns (SaleInfo[] memory) {
        //count active sale
        uint256 length = saleList.length;
        uint256 count = 0;
        for(uint256 i = 0; i < length; i++) {
            if (saleList[i].isActive && !saleList[i].isSold) count++;
        }

        SaleInfo[] memory ret = new SaleInfo[](count);
        count = 0;
        for(uint256 i = 0; i < length; i++) {
            if (saleList[i].isActive && !saleList[i].isSold) {
                ret[count] = saleList[i];
                count++;
            }
        }
        return ret;
    }

    function getSaleCount() external view returns (uint256) {
        return saleList.length;
    }

    function getSales(uint256 _fromIndex, uint256 _count) external view returns (SaleInfo[] memory list, uint256 actualCount) {
        if (_fromIndex >= saleList.length) return (list, 0);
        list = new SaleInfo[](_count);
        actualCount = 0;
        uint256 _toIndex = _fromIndex.add(_count);
        _toIndex = _toIndex <= saleList.length? _toIndex:saleList.length;
        actualCount = _toIndex.sub(_fromIndex);
        for(uint256 i = _fromIndex; i < _toIndex; i++) {
            list[i - _fromIndex] = saleList[i];
        }
    }
}