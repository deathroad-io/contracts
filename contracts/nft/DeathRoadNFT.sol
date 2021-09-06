pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../lib/SignerRecover.sol";

contract DeathRoadNFT is ERC721Enumerable, IDeathRoadNFT, Ownable, SignerRecover, Initializable {
    using SafeMath for uint256;

    address payable public feeTo;
    uint256 public currentId = 0;
    uint256 public currentBoxId = 0;

    bytes[] public Boxes; //encoded value of string
    bytes[] public Packs; //encoded value of string

    mapping(bytes => bool) public mappingBoxes;
    mapping(bytes => bool) public mappingPacks;
    //boxtype => feature : check whether pack type for box type exist
    mapping(bytes => mapping(bytes => bool)) public mappingFeatures;

    mapping(address => bool) public mappingApprover;

    mapping(uint256 => bytes[]) public mappingTokenFeatureNames;

    //feature values is encoded of ['string', 'bytes']
    //where string is feature data type, from which we decode the actual value contained in bytes
    mapping(uint256 => bytes[]) public mappingTokenFeatureValues;

    mapping(address => uint256) public override mappingLuckyCharm;

    mapping(uint256 => Box) public mappingBoxOwner;
    mapping(address => uint256) public override latestTokenMinted;
    address public factory;

    constructor() ERC721("DeathRoadNFT", "DRACE") {}

    function initialize(address _nftFactory) external initializer {
        factory = _nftFactory;
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "Only factory can do this");
        _;
    }

    function getBoxes() public view override returns (bytes[] memory) {
        return Boxes;
    }

    function getPacks() public view override returns (bytes[] memory) {
        return Packs;
    }

    function addBoxes(bytes memory _box) public override onlyFactory {
        require(mappingBoxes[_box] != true);
        mappingBoxes[_box] = true;
        Boxes.push(_box);
    }

    function addPacks(bytes memory _pack) public override onlyFactory {
        require(mappingPacks[_pack] != true);
        mappingPacks[_pack] = true;
        Packs.push(_pack);
    }

    function addFeature(bytes memory _box, bytes memory _feature)
        public
        override
        onlyFactory
    {
        require(mappingBoxes[_box], "addFeature: invalid box type");
        require(
            !mappingFeatures[_box][_feature],
            "addFeature: feature already exist"
        );
        mappingFeatures[_box][_feature] = true;
    }

    function buyBox(
        address _recipient,
        bytes memory _box,
        bytes memory _pack
    ) public override onlyFactory returns (uint256) {
        require(mappingBoxes[_box], "_buyBox: invalid box type");
        require(mappingPacks[_pack], "_buyBox: invalid pack");

        currentBoxId = currentBoxId.add(1);
        uint256 boxId = currentBoxId;

        mappingBoxOwner[boxId].isOpen = false;
        mappingBoxOwner[boxId].owner = _recipient;
        mappingBoxOwner[boxId].box = _box;
        mappingBoxOwner[boxId].pack = _pack;

        return boxId;
    }

    function buyCharm(address _recipient) public override onlyFactory {
        mappingLuckyCharm[_recipient] = mappingLuckyCharm[_recipient].add(1);
    }

    function setBoxOpen(uint256 _boxId, bool _val) public override onlyFactory {
        mappingBoxOwner[_boxId].isOpen = _val;
    }

    //client compute result index off-chain, the function will verify it
    function mint(
        address _recipient,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) external override onlyFactory returns (uint256 _tokenId) {
        currentId = currentId.add(1);
        uint256 tokenId = currentId;
        require(!existTokenFeatures(tokenId), "Token is already");

        _mint(_recipient, tokenId);

        setFeatures(tokenId, _featureNames, _featureValues);
        latestTokenMinted[_recipient] = tokenId;
        return tokenId;
    }

    function burn(uint256 tokenId) external override {
        _burn(tokenId);
    }

    function decreaseCharm(address _addr) external override {
        mappingLuckyCharm[_addr] = mappingLuckyCharm[_addr].sub(1);
    }

    function setFeatures(
        uint256 tokenId,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) public onlyFactory {
        require(!existTokenFeatures(tokenId), "setFeatures: tokenId is exist");

        mappingTokenFeatureNames[tokenId] = _featureNames;
        mappingTokenFeatureValues[tokenId] = _featureValues;
    }

    function updateFeature(address _owner, uint256 tokenId, bytes memory featureName, bytes memory featureValue) public override onlyFactory {
        require(ownerOf(tokenId) == _owner, "updateFeature: tokenId is exist");
        bytes[] memory _curerntFeatureNames = mappingTokenFeatureNames[tokenId];
        for(uint256 i = 0; i < _curerntFeatureNames.length; i++) {
            if (keccak256(_curerntFeatureNames[i]) == keccak256(featureName)) {
                mappingTokenFeatureValues[tokenId][i] = featureValue;
                return;
            }
        }

        //not found
        mappingTokenFeatureNames[tokenId].push(featureName);
        mappingTokenFeatureValues[tokenId].push(featureValue);
    }

    function getTokenFeatures(uint256 tokenId)
        public
        view
        override
        returns (bytes[] memory _featureNames, bytes[] memory)
    {
        return (
            mappingTokenFeatureNames[tokenId],
            mappingTokenFeatureValues[tokenId]
        );
    }

    function existTokenFeatures(uint256 tokenId) public view override returns (bool) {
        if (mappingTokenFeatureNames[tokenId].length == 0) {
            return false;
        }
        return true;
    }

    function isBoxOwner(address _addr, uint256 _boxId)
        external
        view
        override
        returns (bool)
    {
        return mappingBoxOwner[_boxId].owner == _addr;
    }

    function isBoxOpen(uint256 _boxId) external view override returns (bool) {
        return mappingBoxOwner[_boxId].isOpen;
    }
}
