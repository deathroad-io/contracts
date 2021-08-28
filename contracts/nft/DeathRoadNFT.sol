pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interfaces/INotaryNFT.sol";
import "../lib/SignerRecover.sol";

contract DeathRoadNFT is ERC721, Ownable, SignerRecover {
    using SafeMath for uint256;
    address public DRACE;
    address payable public feeTo;
    uint256 currentId = 0;
    uint256 currentBoxId = 0;

    event NewBox(address owner, uint256 boxId);
    event OpenBox(address owner, uint256 boxId, uint256 tokenId);
    event UpgradeToken(
        address owner,
        uint256[3] oldTokenId,
        bool upgradeStatus,
        uint256 tokenId
    );

    bytes32[] public BoxType;

    mapping(bytes32 => bool) public mappingBoxType;
    mapping(bytes32 => bool) public mappingPackType;
    mapping(bytes32 => bytes32[]) public mappingPackTypeOfBox;

    mapping(address => bool) public mappingApprover;

    mapping(uint256 => bytes32[]) public mappingFeatureNames;
    mapping(uint256 => bytes32[]) public mappingFeatureValues;

    mapping(address => uint256) public mappingLuckyCharm;

    struct Box {
        bool isOpen;
        address owner;
        bytes32 boxType; // car, weapon, other,....
        bytes32 packType; // iron, bronze, silver, gold, platinum, diamond
    }
    mapping(uint256 => Box) public mappingBoxOwner;

    modifier onlyBoxOwner(uint256 boxId) {
        require(mappingBoxOwner[boxId].owner == msg.sender);
        _;
    }

    modifier boxNotOpen(uint256 boxId) {
        require(!mappingBoxOwner[boxId].isOpen);
        _;
    }

    constructor(address DRACE_token) ERC721("DeathRoadNFT", "DRACE") {
        DRACE = DRACE_token;
    }

    function getBoxType() public view returns (bytes32[] memory) {
        return BoxType;
    }

    function getPackTypeOfBox(bytes32 _boxType)
        public
        view
        returns (bytes32[] memory)
    {
        return mappingPackTypeOfBox[_boxType];
    }

    function setFeeTo(address payable _feeTo) public onlyOwner {
        feeTo = _feeTo;
    }

    function addBoxType(bytes32 _boxType) public onlyOwner {
        require(mappingBoxType[_boxType] != true);
        mappingBoxType[_boxType] = true;
        BoxType.push(_boxType);
    }

    function addPackType(bytes32 _boxType, bytes32 _packType) public onlyOwner {
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

    function buyBox(
        bytes32 _boxType,
        bytes32 _packType,
        uint256 _amount,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "price expried");
        bytes32 message = keccak256(
            abi.encode("buyBox", msg.sender, _amount, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "buyBox: Price signature invalid"
        );
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _amount);
        _buyBox(_boxType, _packType);
    }

    function buyCharm(
        uint256 _amount,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "price expried");
        bytes32 message = keccak256(
            abi.encode("buyCharm", msg.sender, _amount, _expiryTime)
        );
        require(
            verifySignature(r, s, v, message),
            "Signature data is not correct"
        );
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _amount);
        mappingLuckyCharm[msg.sender] = mappingLuckyCharm[msg.sender]++;
    }

    function buyBoxByNative(
        uint256 _amount,
        bytes32 _boxType,
        bytes32 _packType,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable {
        require(block.timestamp <= _expiryTime, "price expried");
        require(msg.value >= _amount, "transaction lower value");
        bytes32 message = keccak256(
            abi.encode("buyBoxByNative", msg.sender, _amount, _expiryTime, _boxType, _packType)
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
        bytes32[] memory _featureNames,
        bytes32[] memory _featureValues,
        bytes32 r,
        bytes32 s,
        uint8 v,
        bytes32 signedData
    ) public onlyBoxOwner(boxId) boxNotOpen(boxId) {
        require(
            verifySignature(r, s, v, signedData),
            "Signature data is not correct"
        );

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
        bytes32[] memory _featureNames,
        bytes32[] memory _featureValues
    ) internal {
        require(!existFeatures(tokenId));

        mappingFeatureNames[tokenId] = _featureNames;
        mappingFeatureValues[tokenId] = _featureValues;
    }

    function getFeatures(uint256 tokenId)
        public
        view
        returns (bytes32[] memory, bytes32[] memory)
    {
        return (mappingFeatureNames[tokenId], mappingFeatureValues[tokenId]);
    }

    function existFeatures(uint256 tokenId) public view returns (bool) {
        if (mappingFeatureNames[tokenId].length == 0) {
            return false;
        }
        return true;
    }

    struct UpgradeInfo {
        address user;
        bool useCharm;
        bool settled;
        uint256[3] tokenIds;
        bytes32[] targetFeatureNames;
        bytes32[] targetFeatureValues;
        bytes32 userRandomValue;
    }

    mapping(bytes32 => UpgradeInfo) public upgradesInfo;
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
        bytes32[] memory _featureNames,
        bytes32[] memory _featureValues,
        bool _useCharm,
        bytes32 _userRandomValue,
        bytes32 _commitment,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
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

        upgradesInfo[_commitment] = UpgradeInfo({
            user: msg.sender,
            useCharm: _useCharm,
            settled: false,
            tokenIds: _tokenIds,
            targetFeatureNames: _featureNames,
            targetFeatureValues: _featureValues,
            userRandomValue: _userRandomValue
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

        UpgradeInfo storage u = upgradesInfo[commitment];

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
            tokenId = currentId++;
            require(
                !existFeatures(tokenId),
                "settleUpgradeFeatures: Token is already"
            );
            _mint(u.user, tokenId);
            setFeatures(tokenId, u.targetFeatureNames, u.targetFeatureValues);
        }

        u.settled = true;

        emit UpgradeToken(u.user, u.tokenIds, success, tokenId);
    }

    INotaryNFT public notaryHook;
    function setNotaryHook(address _notaryHook) external onlyOwner {
        notaryHook = INotaryNFT(_notaryHook);
    }
    function getUpgradeResult(bytes32 secret) public view returns (bool) {
        return notaryHook.getUpgradeResult(secret, address(this));
    }
}
