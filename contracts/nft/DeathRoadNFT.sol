pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../lib/SignerRecover.sol";

contract DeathRoadNFT is ERC721, Ownable, SignerRecover, Initializable {
    using SafeMath for uint256;

    address public DRACE;
    address payable public feeTo;
    uint256 currentId = 0;
    uint256 currentBoxId = 0;
    address public gameContract;

    struct Box {
        bool isOpen;
        address owner;
        bytes boxType; // car, weapon, other,....
        bytes packType; // iron, bronze, silver, gold, platinum, diamond
    }

    event NewBox(address owner, uint256 boxId);
    event OpenBox(address owner, uint256 boxId, uint256 tokenId);
    event UpgradeToken(
        address owner,
        uint256[3] oldTokenId,
        bool upgradeStatus,
        bool useCharm,
        uint256 tokenId
    );

    bytes[] public BoxType; //encoded value of string

    mapping(bytes => bool) public mappingBoxType;
    mapping(bytes => bool) public mappingPackType;
    mapping(bytes => bytes[]) public mappingPackTypeOfBox;

    mapping(address => bool) public mappingApprover;

    mapping(uint256 => bytes[]) public mappingFeatureNames;

    //feature values is encoded of ['string', 'bytes']
    //where string is feature data type, from which we decode the actual value contained in bytes
    mapping(uint256 => bytes[]) public mappingFeatureValues;

    mapping(address => uint256) public mappingLuckyCharm;

    mapping(uint256 => mapping(bytes => bytes)) mappingTokenSpecialFeatures;

    mapping(uint256 => Box) public mappingBoxOwner;

    modifier onlyBoxOwner(uint256 boxId) {
        require(mappingBoxOwner[boxId].owner == msg.sender, "!not box owner");
        _;
    }

    modifier boxNotOpen(uint256 boxId) {
        require(!mappingBoxOwner[boxId].isOpen);
        _;
    }

    modifier onlyBoxOwnerOrOwner(uint256 boxId) {
        require(
            mappingBoxOwner[boxId].owner == msg.sender || msg.sender == owner(),
            "!not box owner"
        );
        _;
    }

    constructor() ERC721("DeathRoadNFT", "DRACE") {
    }

    function initialize(address DRACE_token, address payable _feeTo, address _notaryHook) external initializer {
        DRACE = DRACE_token;
        feeTo = _feeTo;
        notaryHook = INotaryNFT(_notaryHook);
    }

    function getBoxType() public view returns (bytes[] memory) {
        return BoxType;
    }

    function getPackTypeOfBox(bytes memory _boxType)
        public
        view
        returns (bytes[] memory)
    {
        return mappingPackTypeOfBox[_boxType];
    }

    function setFeeTo(address payable _feeTo) public onlyOwner {
        feeTo = _feeTo;
    }

    function setGameContract(address _gameContract) public onlyOwner {
        gameContract = _gameContract;
    }


    function setSpecialFeatures(uint256 tokenId, bytes memory _name, bytes memory _value,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(ownerOf(tokenId) == msg.sender);

        require(block.timestamp <= _expiryTime, "price expired");
        bytes32 message = keccak256(
            abi.encode(msg.sender, _name, _value, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "buyBox: Price signature invalid"
        );

        mappingTokenSpecialFeatures[tokenId][_name] = _value;
    }

    function setSpecialFeaturesByGameContract(
        uint256 tokenId,
        bytes memory _name,
        bytes memory _value
    ) public {
        require(msg.sender == gameContract);
        mappingTokenSpecialFeatures[tokenId][_name] = _value;
    }

    function getSpecialFeaturesOfToken(uint256 tokenId, bytes memory _name)
        public
        view
        returns (bytes memory _value)
    {
        return mappingTokenSpecialFeatures[tokenId][_name];
    }

    function addBoxType(bytes memory _boxType) public onlyOwner {
        require(mappingBoxType[_boxType] != true);
        mappingBoxType[_boxType] = true;
        BoxType.push(_boxType);
    }

    function addPackType(bytes memory _boxType, bytes memory _packType)
        public
        onlyOwner
    {
        require(mappingBoxType[_boxType] == true);
        require(mappingPackType[_packType] != true);
        mappingPackType[_packType] = true;
        mappingPackTypeOfBox[_boxType].push(_packType);
    }

    function _buyBox(bytes memory _boxType, bytes memory _packType) internal {
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

    function buyBox(
        bytes memory _boxType,
        bytes memory _packType,
        uint256 _price,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "price expired");
        bytes32 message = keccak256(
            abi.encode("buyBox", msg.sender, _boxType, _packType, _price, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "buyBox: Price signature invalid"
        );
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _price);
        _buyBox(_boxType, _packType);
    }

    function buyCharm(
        uint256 _price,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "price expried");
        bytes32 message = keccak256(
            abi.encode("buyCharm", msg.sender, _price, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "Signature data is not correct"
        );
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _price);
        mappingLuckyCharm[msg.sender] = mappingLuckyCharm[msg.sender]++;
    }

    function buyBoxByNative(
        uint256 _price,
        bytes memory _boxType,
        bytes memory _packType,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable {
        require(block.timestamp <= _expiryTime, "price expired");
        require(msg.value >= _price, "transaction lower value");
        bytes32 message = keccak256(
            abi.encode("buyBoxByNative", msg.sender, _boxType, _packType, _price, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "Signature data is not correct"
        );
        feeTo.transfer(msg.value);
        _buyBox(_boxType, _packType);
    }

    function openBox(
        uint256 boxId,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public onlyBoxOwnerOrOwner(boxId) boxNotOpen(boxId) {
        if (msg.sender != owner()) {
            require(
                block.timestamp <= _expiryTime,
                "openBox: commitment expried"
            );
            require(
                _featureNames.length == _featureValues.length,
                "openBox:invalid input length"
            );
            bytes32 message = keccak256(
                abi.encode(
                    "openBox",
                    msg.sender,
                    boxId,
                    _featureNames,
                    _featureValues,
                    _expiryTime
                )
            );
            require(
                verifySignature(r, s, v, message),
                "Signature data is not correct"
            );
        }


        currentId = currentId++;
        uint256 tokenId = currentId;
        require(!existFeatures(tokenId), "Token is already");

        _mint(msg.sender, tokenId);

        setFeatures(tokenId, _featureNames, _featureValues);

        emit OpenBox(msg.sender, boxId, tokenId);
    }

    function addApprover(address _approver) public onlyOwner {
        mappingApprover[_approver] = true;
    }

    function removeApprover(address _approver) public onlyOwner {
        mappingApprover[_approver] = false;
    }
    function isApprover(address _approver) public view returns (bool) {
        return mappingApprover[_approver];
    }

    function verifySignature(
        bytes32 r,
        bytes32 s,
        uint8 v,
        bytes32 signedData
    ) internal view returns (bool) {
        address signer = recoverSigner(r, s, v, signedData);

        return mappingApprover[signer];
    }

    function setFeatures(
        uint256 tokenId,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) internal {
        require(!existFeatures(tokenId));

        mappingFeatureNames[tokenId] = _featureNames;
        mappingFeatureValues[tokenId] = _featureValues;
    }

    function getFeatures(uint256 tokenId)
        public
        view
        returns (bytes[] memory _featureNames, bytes[] memory)
    {
        return (mappingFeatureNames[tokenId], mappingFeatureValues[tokenId]);
    }

    function existFeatures(uint256 tokenId) public view returns (bool) {
        if (mappingFeatureNames[tokenId].length == 0) {
            return false;
        }
        return true;
    }

    mapping(bytes32 => IDeathRoadNFT.UpgradeInfo) public upgradesInfo;
    mapping(address => bytes32[]) public allUpgrades;
    event CommitUpgradeFeature(address user, bytes32 commitment);

    //upgrade consists of 2 steps following commit-reveal scheme to ensure transparency and security
    //1. commitment by sending hash of a secret value
    //2. reveal the secret and the upgrades randomly
    //_tokenIds: tokens used for upgrades
    //_featureNames: of new NFT
    //_featureValues: of new NFT
    //_useCharm: burn the input tokens or not when failed
    function commitUpgradeFeatures(
        uint256[3] memory _tokenIds,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues,
        bool _useCharm,
        uint256 _expiryTime,
        bytes32 _commitment,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(
            block.timestamp <= _expiryTime,
            "commitUpgradeFeatures: commitment expried"
        );
        require(
            upgradesInfo[_commitment].user == address(0),
            "commitment overlap"
        );
        if (_useCharm) {
            require(
                mappingLuckyCharm[msg.sender] > 0,
                "commitUpgradeFeatures: you need to buy charm"
            );
        }
        //verify infor
        bytes32 message = keccak256(
            abi.encode(
                _tokenIds,
                _featureNames,
                _featureValues,
                _useCharm,
                _commitment
            )
        );
        require(
            verifySignature(r, s, v, message),
            "commitUpgradeFeatures:Signature data is not correct"
        );

        //need to lock token Ids here
        transferFrom(msg.sender, address(this), _tokenIds[0]);
        transferFrom(msg.sender, address(this), _tokenIds[1]);
        transferFrom(msg.sender, address(this), _tokenIds[2]);

        allUpgrades[msg.sender].push(_commitment);

        upgradesInfo[_commitment] = IDeathRoadNFT.UpgradeInfo({
            user: msg.sender,
            useCharm: _useCharm,
            settled: false,
            tokenIds: _tokenIds,
            targetFeatureNames: _featureNames,
            targetFeatureValues: _featureValues,
            previousBlockHash: blockhash(block.number - 1)
        });
        emit CommitUpgradeFeature(msg.sender, _commitment);
    }

    function settleUpgradeFeatures(bytes32 secret) external {
        bytes32 commitment = keccak256(abi.encode(secret));
        require(
            upgradesInfo[commitment].user != address(0),
            "settleUpgradeFeatures: commitment not exist"
        );
        require(
            !upgradesInfo[commitment].settled,
            "settleUpgradeFeatures: updated already settled"
        );

        bool success = getUpgradeResult(secret);

        IDeathRoadNFT.UpgradeInfo storage u = upgradesInfo[commitment];

        if (success || !u.useCharm) {
            for (uint256 i = 0; i < u.tokenIds.length; i++) {
                //burn NFTs
                _burn(u.tokenIds[i]);
            }
        }
        if (!success && u.useCharm) {
            mappingLuckyCharm[u.user] = mappingLuckyCharm[u.user].sub(1);

            //returning NFTs back
            transferFrom(address(this), msg.sender, u.tokenIds[0]);
            transferFrom(address(this), msg.sender, u.tokenIds[1]);
            transferFrom(address(this), msg.sender, u.tokenIds[2]);
        }
        uint256 tokenId = 0;
        if (success) {
            currentId = currentId++;
            tokenId = currentId;
            require(
                !existFeatures(tokenId),
                "settleUpgradeFeatures: Token is already"
            );
            _mint(u.user, tokenId);
            setFeatures(tokenId, u.targetFeatureNames, u.targetFeatureValues);
        }

        u.settled = true;

        emit UpgradeToken(u.user, u.tokenIds, success, u.useCharm, tokenId);
    }

    INotaryNFT public notaryHook;

    function setNotaryHook(address _notaryHook) external onlyOwner {
        notaryHook = INotaryNFT(_notaryHook);
    }

    function getUpgradeResult(bytes32 secret) public view returns (bool) {
        return notaryHook.getUpgradeResult(secret, address(this));
    }

    //decode functions
    function decodeType(bytes memory _type)
        external
        view
        returns (string memory)
    {
        string memory _decoded = abi.decode(_type, (string));
        return _decoded;
    }

    function decodeFeatureValue(bytes memory _featureValue)
        external
        view
        returns (string memory _dataType, bytes memory _encodedValue)
    {
        (_dataType, _encodedValue) = abi.decode(_featureValue, (string, bytes));
        return (_dataType, _encodedValue);
    }
}
