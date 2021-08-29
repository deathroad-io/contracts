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
        bytes box; // car, gun, rocket, other,...
        bytes pack; // 1star, 2star, 3star, 4star, 5star, legend,...
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

    bytes[] public Boxes; //encoded value of string
    bytes[] public Packs; //encoded value of string

    mapping(bytes => bool) public mappingBoxes;
    mapping(bytes => bool) public mappingPacks;
    //boxtype => feature : check whether pack type for box type exist
    mapping(bytes => mapping (bytes => bool)) public mappingFeatures;
    mapping(bytes => bytes[]) public mappingFeaturesOfBox;

    mapping(address => bool) public mappingApprover;

    mapping(uint256 => bytes[]) public mappingTokenFeatureNames;

    //feature values is encoded of ['string', 'bytes']
    //where string is feature data type, from which we decode the actual value contained in bytes
    mapping(uint256 => bytes[]) public mappingTokenFeatureValues;

    mapping(address => uint256) public mappingLuckyCharm;

    mapping(uint256 => mapping(bytes => bytes)) mappingTokenSpecialFeatures;

    mapping(uint256 => Box) public mappingBoxOwner;

    modifier onlyBoxOwner(uint256 boxId) {
        require(mappingBoxOwner[boxId].owner == msg.sender, "!not box owner");
        _;
    }

    modifier boxNotOpen(uint256 boxId) {
        require(!mappingBoxOwner[boxId].isOpen, "box already open");
        _;
    }

    modifier onlyBoxOwnerOrOwner(uint256 boxId) {
        require(
            mappingBoxOwner[boxId].owner == msg.sender || msg.sender == owner(),
            "!not box owner"
        );
        _;
    }

    constructor() ERC721("DeathRoadNFT", "DRACE") {}

    function initialize(
        address DRACE_token,
        address payable _feeTo,
        address _notaryHook
    ) external initializer {
        DRACE = DRACE_token;
        feeTo = _feeTo;
        notaryHook = INotaryNFT(_notaryHook);
    }

    function getBoxes() public view returns (bytes[] memory) {
        return Boxes;
    }
    function getPacks() public view returns (bytes[] memory) {
        return Packs;
    }

    function getFeaturesOfBox(bytes memory _box)
        public
        view
        returns (bytes[] memory)
    {
        return mappingFeaturesOfBox[_box];
    }

    function setFeeTo(address payable _feeTo) public onlyOwner {
        feeTo = _feeTo;
    }

    function setGameContract(address _gameContract) public onlyOwner {
        gameContract = _gameContract;
    }

    function setSpecialFeatures(
        uint256 tokenId,
        bytes memory _name,
        bytes memory _value,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(ownerOf(tokenId) == msg.sender, "setSpecialFeatures: msg.sender not token owner");

        require(block.timestamp <= _expiryTime, "Expired");
        bytes32 message = keccak256(
            abi.encode(msg.sender, _name, _value, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "setSpecialFeatures: Signature invalid"
        );

        mappingTokenSpecialFeatures[tokenId][_name] = _value;
    }

    function setSpecialFeaturesByGameContract(
        uint256 tokenId,
        bytes memory _name,
        bytes memory _value
    ) public {
        require(msg.sender == gameContract, "setSpecialFeaturesByGameContract: caller is not the game contract");
        mappingTokenSpecialFeatures[tokenId][_name] = _value;
    }

    function getSpecialFeaturesOfToken(uint256 tokenId, bytes memory _name)
        public
        view
        returns (bytes memory _value)
    {
        return mappingTokenSpecialFeatures[tokenId][_name];
    }

    function addBoxes(bytes memory _box) public onlyOwner {
        require(mappingBoxes[_box] != true);
        mappingBoxes[_box] = true;
        Boxes.push(_box);
    }

    function addPacks(bytes memory _pack) public onlyOwner {
        require(mappingPacks[_pack] != true);
        mappingPacks[_pack] = true;
        Packs.push(_pack);
    }

    function addFeature(bytes memory _box, bytes memory _feature)
        public
        onlyOwner
    {
        require(mappingBoxes[_box], "addFeature: invalid box type");
        require(!mappingFeatures[_box][_feature], "addFeature: feature already exist");
        mappingFeatures[_box][_feature] = true;
        mappingFeaturesOfBox[_box].push(_feature);
    }

    function _buyBox(bytes memory _box, bytes memory _pack) internal {
        require(mappingBoxes[_box], "_buyBox: invalid box type");
        require(mappingPacks[_pack], "_buyBox: invalid pack");

        currentBoxId = currentBoxId.add(1);
        uint256 boxId = currentBoxId;

        mappingBoxOwner[boxId].isOpen = false;
        mappingBoxOwner[boxId].owner = msg.sender;
        mappingBoxOwner[boxId].box = _box;
        mappingBoxOwner[boxId].pack = _pack;

        emit NewBox(msg.sender, boxId);
    }

    function buyBox(
        bytes memory _box,
        bytes memory _pack,
        uint256 _price,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "Expired");
        bytes32 message = keccak256(
            abi.encode(
                "buyBox",
                msg.sender,
                _box,
                _pack,
                _price,
                _expiryTime
            )
        );
        require(
            verifySignature(r, s, v, message),
            "buyBox: Signature invalid"
        );
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _price);
        _buyBox(_box, _pack);
    }

    function buyCharm(
        uint256 _price,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "Expired");
        bytes32 message = keccak256(
            abi.encode("buyCharm", msg.sender, _price, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "Signature invalid"
        );
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _price);
        mappingLuckyCharm[msg.sender] = mappingLuckyCharm[msg.sender].add(1);
    }

    function buyBoxByNative(
        uint256 _price,
        bytes memory _box,
        bytes memory _pack,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable {
        require(block.timestamp <= _expiryTime, "Expired");
        require(msg.value >= _price, "transaction lower value");
        bytes32 message = keccak256(
            abi.encode(
                "buyBoxByNative",
                msg.sender,
                _box,
                _pack,
                _price,
                _expiryTime
            )
        );
        require(
            verifySignature(r, s, v, message),
            "Signature invalid"
        );
        feeTo.transfer(msg.value);
        _buyBox(_box, _pack);
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
                "openBox: Expired"
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
                "Signature invalid"
            );
        }

        currentId = currentId.add(1);
        uint256 tokenId = currentId;
        require(!existTokenFeatures(tokenId), "Token is already");

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
        require(!existTokenFeatures(tokenId), "setTokenFeatures: tokenId is exist");

        mappingTokenFeatureNames[tokenId] = _featureNames;
        mappingTokenFeatureValues[tokenId] = _featureValues;
    }

    function getTokenFeatures(uint256 tokenId)
        public
        view
        returns (bytes[] memory _featureNames, bytes[] memory)
    {
        return (mappingTokenFeatureNames[tokenId], mappingTokenFeatureValues[tokenId]);
    }

    function existTokenFeatures(uint256 tokenId) public view returns (bool) {
        if (mappingTokenFeatureNames[tokenId].length == 0) {
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
        uint256 _successRate,
        bool _useCharm,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(
            _successRate < 1000,
            "commitUpgradeFeatures: _successRate too high"
        );
        require(
            block.timestamp <= _expiryTime,
            "commitUpgradeFeatures: commitment expired"
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
                _successRate,
                _useCharm,
                _commitment,
                _expiryTime
            )
        );
        require(
            verifySignature(r, s, v, message),
            "commitUpgradeFeatures:Signature invalid"
        );

        //need to lock token Ids here
        transferFrom(msg.sender, address(this), _tokenIds[0]);
        transferFrom(msg.sender, address(this), _tokenIds[1]);
        transferFrom(msg.sender, address(this), _tokenIds[2]);

        allUpgrades[msg.sender].push(_commitment);

        upgradesInfo[_commitment] = IDeathRoadNFT.UpgradeInfo({
            user: msg.sender,
            useCharm: _useCharm,
            successRate: _successRate,
            upgradeStatus: false,
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
        bool shouldBurn = true;
        if (!success && u.useCharm) {
            if (mappingLuckyCharm[u.user] > 0) {
                mappingLuckyCharm[u.user] = mappingLuckyCharm[u.user].sub(1);

                //returning NFTs back
                transferFrom(address(this), msg.sender, u.tokenIds[0]);
                transferFrom(address(this), msg.sender, u.tokenIds[1]);
                transferFrom(address(this), msg.sender, u.tokenIds[2]);
                shouldBurn = false;
            }
        }
        if (shouldBurn) {
            //burning all input NFTs
            _burn(u.tokenIds[0]);
            _burn(u.tokenIds[1]);
            _burn(u.tokenIds[2]);
        }

        uint256 tokenId = 0;
        if (success) {
            currentId = currentId.add(1);
            tokenId = currentId;
            require(
                !existTokenFeatures(tokenId),
                "settleUpgradeFeatures: Token is already"
            );
            _mint(u.user, tokenId);
            setFeatures(tokenId, u.targetFeatureNames, u.targetFeatureValues);
        }
        u.upgradeStatus = success;
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
