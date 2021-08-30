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

    //commit reveal needs 2 steps, the reveal step needs to pay fee by bot, this fee is to compensate for bots
    uint256 public SETTLE_FEE = 0.005 ether;
    address payable public SETTLE_FEE_RECEIVER;

    bytes[] public Boxes; //encoded value of string
    bytes[] public Packs; //encoded value of string

    mapping(bytes => bool) public mappingBoxes;
    mapping(bytes => bool) public mappingPacks;
    //boxtype => feature : check whether pack type for box type exist
    mapping(bytes => mapping(bytes => bool)) public mappingFeatures;
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

    function setSettleFee(uint256 _fee) external onlyOwner {
        SETTLE_FEE = _fee;
    }
    function setSettleFeeReceiver(address payable _bot) external onlyOwner {
        SETTLE_FEE_RECEIVER = _bot;
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
        require(
            ownerOf(tokenId) == msg.sender,
            "setSpecialFeatures: msg.sender not token owner"
        );

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
        require(
            msg.sender == gameContract,
            "setSpecialFeaturesByGameContract: caller is not the game contract"
        );
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
        require(
            !mappingFeatures[_box][_feature],
            "addFeature: feature already exist"
        );
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
            abi.encode("buyBox", msg.sender, _box, _pack, _price, _expiryTime)
        );
        require(verifySignature(r, s, v, message), "buyBox: Signature invalid");
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
        require(verifySignature(r, s, v, message), "Signature invalid");
        IERC20 erc20 = IERC20(DRACE);
        erc20.transferFrom(msg.sender, feeTo, _price);
        mappingLuckyCharm[msg.sender] = mappingLuckyCharm[msg.sender].add(1);
    }

    mapping(bytes32 => IDeathRoadNFT.OpenBoxInfo) public openBoxInfo;
    mapping(address => bytes32[]) public allOpenBoxes;
    mapping(uint256 => bool) public commitedBoxes;
    event CommitOpenBox(address user, bytes32 commitment);

    function getBasicOpenBoxInfo(bytes32 commitment)
        external
        view
        returns (
            IDeathRoadNFT.OpenBoxBasicInfo memory
        )
    {
        return IDeathRoadNFT.OpenBoxBasicInfo(openBoxInfo[commitment].user,
            openBoxInfo[commitment].boxId,
            openBoxInfo[commitment].totalRate,
            openBoxInfo[commitment].featureNamesSet,
            openBoxInfo[commitment].featureValuesSet,
            openBoxInfo[commitment].previousBlockHash);
    }

    function getSuccessRateRange(bytes32 commitment, uint256 _index) external view returns (uint256[2] memory) {
        return openBoxInfo[commitment].successRateRanges[_index];
    }

    function commitOpenBox(
        uint256 boxId,
        bytes[][] memory _featureNamesSet,
        bytes[][] memory _featureValuesSet,
        uint256[] memory _successRates,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable onlyBoxOwner(boxId) boxNotOpen(boxId) {
        require(msg.value == SETTLE_FEE, "commitOpenBox: must pay settle fee");
        SETTLE_FEE_RECEIVER.transfer(msg.value);
        require(!commitedBoxes[boxId], "commitOpenBox: box already commited");
        commitedBoxes[boxId] = true;
        require(
            block.timestamp <= _expiryTime,
            "commitOpenBox: commitment expired"
        );
        require(
            openBoxInfo[_commitment].user == address(0),
            "commitOpenBox:commitment overlap"
        );

        require(
            _featureNamesSet.length == _featureValuesSet.length &&
                _featureNamesSet.length == _successRates.length,
            "commitOpenBox:invalid input length"
        );

        bytes32 message = keccak256(
            abi.encode(
                "commitOpenBox",
                msg.sender,
                boxId,
                _featureNamesSet,
                _featureValuesSet,
                _successRates,
                _commitment,
                _expiryTime
            )
        );
        require(verifySignature(r, s, v, message), "Signature invalid");

        IDeathRoadNFT.OpenBoxInfo storage info = openBoxInfo[_commitment];
        //compute successRateRange
        uint256 total = 0;
        for (uint256 i; i < _successRates.length; i++) {
            info.successRateRanges[i][0] = total;
            total = total.add(_successRates[i]);
            info.successRateRanges[i][1] = total;
        }
        info.totalRate = total;
        info.user = msg.sender;
        info.boxId = boxId;
        info.featureNamesSet = _featureNamesSet;
        info.featureValuesSet = _featureValuesSet;
        info.previousBlockHash = blockhash(block.number - 1);
        allOpenBoxes[msg.sender].push(_commitment);

        emit CommitOpenBox(msg.sender, _commitment);
    }

    //in case server lose secret, it basically revoke box for user to open again
    function revokeBoxId(uint256 boxId) external onlyOwner {
        commitedBoxes[boxId] = false;
    }

    //client compute result index off-chain, the function will verify it
    function settleOpenBox(bytes32 secret, uint256 _resultIndex) external {
        bytes32 commitment = keccak256(abi.encode(secret));
        require(
            openBoxInfo[commitment].user != address(0),
            "settleOpenBox: commitment not exist"
        );
        require(commitedBoxes[openBoxInfo[commitment].boxId], "settleOpenBox: box must be committed");
        require(
            !openBoxInfo[commitment].settled,
            "settleOpenBox: already settled"
        );
        openBoxInfo[commitment].settled = true;
        openBoxInfo[commitment].openBoxStatus = true;
        require(notaryHook.getOpenBoxResult(secret, _resultIndex, address(this)), "settleOpenBox: incorrect random result");

        currentId = currentId.add(1);
        uint256 tokenId = currentId;
        require(!existTokenFeatures(tokenId), "Token is already");

        _mint( openBoxInfo[commitment].user, tokenId);

        setFeatures(tokenId, openBoxInfo[commitment].featureNamesSet[_resultIndex], openBoxInfo[commitment].featureValuesSet[_resultIndex]);

        emit OpenBox(openBoxInfo[commitment].user, openBoxInfo[commitment].boxId, tokenId);
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
        require(
            !existTokenFeatures(tokenId),
            "setTokenFeatures: tokenId is exist"
        );

        mappingTokenFeatureNames[tokenId] = _featureNames;
        mappingTokenFeatureValues[tokenId] = _featureValues;
    }

    function getTokenFeatures(uint256 tokenId)
        public
        view
        returns (bytes[] memory _featureNames, bytes[] memory)
    {
        return (
            mappingTokenFeatureNames[tokenId],
            mappingTokenFeatureValues[tokenId]
        );
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
    ) public payable {
        require(msg.value == SETTLE_FEE, "commitOpenBox: must pay settle fee");
        SETTLE_FEE_RECEIVER.transfer(msg.value);
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
}
