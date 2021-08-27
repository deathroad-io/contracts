pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract DeathRoadNFT is ERC721, Ownable {

    address public DRACE;
    address payable public feeTo;
    uint256 currentId = 0;
    uint256 currentBoxId = 0;

    event NewBox(address owner, uint256 boxId);
    event OpenBox(address owner, uint256 boxId, uint256 tokenId);
    event UpgradeToken(address owner, uint256[3] oldTokenId, bool upgradeStatus, uint256 tokenId);

    bytes32[] public BoxType;

    mapping (bytes32 => bool) public mappingBoxType;
    mapping (bytes32 => bool) public mappingPackType;
    mapping (bytes32 => bytes32[]) public mappingPackTypeOfBox;

    mapping (address => bool) public mappingApprover;

    mapping (uint256 => bytes32[]) mappingFeatureNames;
    mapping (uint256 => bytes32[]) mappingFeatureValues;

    mapping (address => uint256) mappingLuckyCharm;

    struct Box {
        bool isOpen;
        address owner;
        bytes32 boxType; // car, weapon, other,....
        bytes32 packType; // iron, bronze, silver, gold, platinum, diamond
    }
    mapping (uint256 => Box) public mappingBoxOwner;

    modifier onlyBoxOwner(uint256 boxId) {
        require(mappingBoxOwner[boxId].owner == msg.sender);
        _;
    }

    modifier boxNotOpen(uint256 boxId) {
        require(!mappingBoxOwner[boxId].isOpen);
        _;
    }


    constructor (address DRACE_token) ERC721("DeathRoadNFT", "DRACE") {
        DRACE = DRACE_token;
    }

    function getBoxType() public view returns(bytes32[] memory) {
        return BoxType;
    }

    function getPackTypeOfBox(bytes32 _boxType) public view returns(bytes32[] memory) {
        return mappingPackTypeOfBox[_boxType];
    }

    function setFeeTo(address payable _feeTo) public onlyOwner {
        feeTo = _feeTo;
    }

    function addBoxType(bytes32 _boxType) onlyOwner public {
        require(mappingBoxType[_boxType] != true);
        mappingBoxType[_boxType] = true;
        BoxType.push(_boxType);
    }

    function addPackType(bytes32 _boxType, bytes32 _packType) onlyOwner public {
        require(mappingBoxType[_boxType] == true);
        require(mappingPackType[_packType] != true);
        mappingPackType[_packType] = true;
        mappingPackTypeOfBox[_boxType].push(_packType);
    }

    function _buyBox(bytes32 _boxType, bytes32 _packType) internal {
        require(mappingBoxType[_boxType]);
        require(mappingPackType[_packType]);

        currentBoxId = currentBoxId++;
        uint256 boxId = currentBoxId;

        mappingBoxOwner[boxId].isOpen = false;
        mappingBoxOwner[boxId].owner = msg.sender;
        mappingBoxOwner[boxId].boxType = _boxType;
        mappingBoxOwner[boxId].packType = _packType;

        emit NewBox(msg.sender, boxId);
    }

    function buyBox(bytes32 _boxType, bytes32 _packType, uint256 _amount, bytes32 r, bytes32 s, uint8 v, bytes32 signedData) public {
        require(verifySignature(r, s, v, signedData), "Signature data is not correct");
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _amount);
        _buyBox(_boxType, _packType);
    }

    function buyCharm(uint256 _amount, bytes32 r, bytes32 s, uint8 v, bytes32 signedData) public {
        require(verifySignature(r, s, v, signedData), "Signature data is not correct");
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _amount);
        mappingLuckyCharm[msg.sender] = mappingLuckyCharm[msg.sender]++;
    }

    function buyBoxByNative(bytes32 _boxType, bytes32 _packType, bytes32 r, bytes32 s, uint8 v, bytes32 signedData) public payable {
        require(verifySignature(r, s, v, signedData), "Signature data is not correct");
        feeTo.transfer(msg.value);
        _buyBox(_boxType, _packType);
    }

    function openBox(uint256 boxId, bytes32[] memory _featureNames, bytes32[] memory _featureValues, bytes32 r, bytes32 s, uint8 v, bytes32 signedData) onlyBoxOwner(boxId) boxNotOpen(boxId) public {
        require(verifySignature(r, s, v, signedData), "Signature data is not correct");

        currentId = currentId++;
        uint256 tokenId = currentId;
        require(!existFeatures(tokenId), "Token is already");

        _mint(msg.sender, tokenId);
        setFeatures(tokenId, _featureNames, _featureValues);

        emit OpenBox(msg.sender, boxId, tokenId);
    }

    function addApprover(address _approver) onlyOwner public {
        mappingApprover[_approver] = true;
    }

    function removeApprover(address _approver) onlyOwner public {
        mappingApprover[_approver] = false;
    }


    function verifySignature(bytes32 r, bytes32 s, uint8 v, bytes32 signedData) internal view returns (bool) {
        address signer = ecrecover(keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", signedData)
            ), v, r, s);

        return mappingApprover[signer];
    }


    function setFeatures(uint256 tokenId, bytes32[] memory _featureNames, bytes32[] memory _featureValues) internal {
        require(!existFeatures(tokenId));

        mappingFeatureNames[tokenId] = _featureNames;
        mappingFeatureValues[tokenId] = _featureValues;
    }

    function getFeatures(uint256 tokenId) public view returns (bytes32[] memory, bytes32[] memory) {
        return (mappingFeatureNames[tokenId], mappingFeatureValues[tokenId]);
    }

    function existFeatures(uint256 tokenId) public view returns(bool) {
        if (mappingFeatureNames[tokenId].length == 0) {
            return false;
        }
        return true;
    }

    function upgradeFeatures(uint256[3] memory tokenIds, bytes32[] memory _featureNames, bool fail, bool useCharm, bytes32[] memory _featureValues, bytes32 r, bytes32 s, uint8 v, bytes32 signedData) public {
        require(verifySignature(r, s, v, signedData), "Signature data is not correct");
        if (useCharm) {
            require(mappingLuckyCharm[msg.sender] > 0);
        }
        uint256 i;
        for (i = 0; i < tokenIds.length; i++) {
            require(ownerOf(tokenIds[i]) == msg.sender, "You are not the owner of one of these NFTs");
        }
        if (!(fail && useCharm)) {
            for (i = 0; i < tokenIds.length; i++) {
                transferFrom(msg.sender, address(0), tokenIds[i]);
            }
        }
        uint256 tokenId = 0;
        if (!fail) {
            tokenId = currentId++;
            require(!existFeatures(tokenId), "Token is already");
            _mint(msg.sender, tokenId);
            setFeatures(tokenId, _featureNames, _featureValues);
        }

        emit UpgradeToken(msg.sender, tokenIds, fail, tokenId);
    }
}
