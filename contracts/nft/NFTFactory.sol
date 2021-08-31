pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../lib/SignerRecover.sol";

contract NFTFactory is Ownable, SignerRecover, Initializable {
    using SafeMath for uint256;

    address public DRACE;
    address payable public feeTo;
    address public gameContract;

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

    mapping(address => bool) public mappingApprover;

    IDeathRoadNFT public nft;
    constructor() {}

    function initialize(
        address _nft,
        address DRACE_token,
        address payable _feeTo,
        address _notaryHook
    ) external initializer {
        nft = IDeathRoadNFT(_nft);
        DRACE = DRACE_token;
        feeTo = _feeTo;
        notaryHook = INotaryNFT(_notaryHook);
    }

    modifier onlyBoxOwner(uint256 boxId) {
        require(nft.isBoxOwner(msg.sender, boxId), "!not box owner");
        _;
    }

    modifier boxNotOpen(uint256 boxId) {
        require(!nft.isBoxOpen(boxId), "box already open");
        _;
    }

    function setSettleFee(uint256 _fee) external onlyOwner {
        SETTLE_FEE = _fee;
    }
    function setSettleFeeReceiver(address payable _bot) external onlyOwner {
        SETTLE_FEE_RECEIVER = _bot;
    }

    function getBoxes() public view returns (bytes[] memory) {
        return nft.getBoxes();
    }

    function getPacks() public view returns (bytes[] memory) {
        return nft.getPacks();
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
            nft.ownerOf(tokenId) == msg.sender,
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
        
        nft.setTokenSpecialFeatures(tokenId, _name, _value);
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
        nft.setTokenSpecialFeatures(tokenId, _name, _value);
    }

    function addBoxes(bytes memory _box) public onlyOwner {
        nft.addBoxes(_box);
    }

    function addPacks(bytes memory _pack) public onlyOwner {
        nft.addPacks(_pack);
    }

    function addFeature(bytes memory _box, bytes memory _feature)
        public
        onlyOwner
    {
        nft.addFeature(_box, _feature);
    }

    function _buyBox(bytes memory _box, bytes memory _pack) internal {
        uint256 boxId = nft.buyBox(msg.sender, _box, _pack);
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
        nft.buyCharm(msg.sender);
    }

    mapping(bytes32 => INFTFactory.OpenBoxInfo) public openBoxInfo;
    mapping(address => bytes32[]) public allOpenBoxes;
    mapping(uint256 => bool) public commitedBoxes;
    event CommitOpenBox(address user, uint256 boxId, bytes32 commitment);

    function getBasicOpenBoxInfo(bytes32 commitment)
        external
        view
        returns (
            INFTFactory.OpenBoxBasicInfo memory
        )
    {
        return INFTFactory.OpenBoxBasicInfo(openBoxInfo[commitment].user,
            openBoxInfo[commitment].boxId,
            openBoxInfo[commitment].totalRate,
            openBoxInfo[commitment].featureNames,
            openBoxInfo[commitment].featureValuesSet,
            openBoxInfo[commitment].previousBlockHash);
    }

    function getSuccessRateRange(bytes32 commitment, uint256 _index) external view returns (uint256[2] memory) {
        return openBoxInfo[commitment].successRateRanges[_index];
    }

    function commitOpenBox(
        uint256 boxId,
        bytes[] memory _featureNames,    //all have same set of feature sames
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
            _featureNames.length == _featureValuesSet[0].length &&
                _featureValuesSet.length == _successRates.length,
            "commitOpenBox:invalid input length"
        );

        bytes32 message = keccak256(
            abi.encode(
                "commitOpenBox",
                msg.sender,
                boxId,
                _featureNames,
                _featureValuesSet,
                _successRates,
                _commitment,
                _expiryTime
            )
        );
        require(verifySignature(r, s, v, message), "Signature invalid");

        INFTFactory.OpenBoxInfo storage info = openBoxInfo[_commitment];
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
        info.featureNames = _featureNames;
        info.featureValuesSet = _featureValuesSet;
        info.previousBlockHash = blockhash(block.number - 1);
        allOpenBoxes[msg.sender].push(_commitment);

        emit CommitOpenBox(msg.sender, boxId, _commitment);
    }

    //in case server lose secret, it basically revoke box for user to open again
    function revokeBoxId(uint256 boxId) external onlyOwner {
        commitedBoxes[boxId] = false;
    }

    //client compute result index off-chain, the function will verify it
    function settleOpenBox(bytes32 secret, uint256 _resultIndex) external {
        bytes32 commitment = keccak256(abi.encode(secret));
        INFTFactory.OpenBoxInfo storage info = openBoxInfo[commitment];
        require(
            info.user != address(0),
            "settleOpenBox: commitment not exist"
        );
        require(commitedBoxes[info.boxId], "settleOpenBox: box must be committed");
        require(
            !info.settled,
            "settleOpenBox: already settled"
        );
        info.settled = true;
        info.openBoxStatus = true;
        require(notaryHook.getOpenBoxResult(secret, _resultIndex, address(this)), "settleOpenBox: incorrect random result");

        //mint
        uint256 tokenId = nft.mint(info.user, info.featureNames, info.featureValuesSet[_resultIndex]);

        nft.setBoxOpen(info.boxId, true);

        emit OpenBox(info.user, info.boxId, tokenId);
    }

    function addApprover(address _approver, bool _val) public onlyOwner {
        mappingApprover[_approver] = _val;
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

    function getTokenFeatures(uint256 tokenId)
        public
        view
        returns (bytes[] memory _featureNames, bytes[] memory)
    {
        return nft.getTokenFeatures(tokenId);
    }

    function existTokenFeatures(uint256 tokenId) public view returns (bool) {
        return nft.existTokenFeatures(tokenId);
    }

    mapping(bytes32 => INFTFactory.UpgradeInfo) public upgradesInfo;
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
                nft.mappingLuckyCharm(msg.sender) > 0,
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
        nft.transferFrom(msg.sender, address(this), _tokenIds[0]);
        nft.transferFrom(msg.sender, address(this), _tokenIds[1]);
        nft.transferFrom(msg.sender, address(this), _tokenIds[2]);

        allUpgrades[msg.sender].push(_commitment);

        upgradesInfo[_commitment] = INFTFactory.UpgradeInfo({
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

        INFTFactory.UpgradeInfo storage u = upgradesInfo[commitment];

        if (success || !u.useCharm) {
            for (uint256 i = 0; i < u.tokenIds.length; i++) {
                //burn NFTs
                nft.burn(u.tokenIds[i]);
            }
        }
        bool shouldBurn = true;
        if (!success && u.useCharm) {
            if (nft.mappingLuckyCharm(u.user) > 0) {
                nft.decreaseCharm(u.user);

                //returning NFTs back
                nft.transferFrom(address(this), u.user, u.tokenIds[0]);
                nft.transferFrom(address(this), u.user, u.tokenIds[1]);
                nft.transferFrom(address(this), u.user, u.tokenIds[2]);
                shouldBurn = false;
            }
        }
        if (shouldBurn) {
            //burning all input NFTs
            nft.burn(u.tokenIds[0]);
            nft.burn(u.tokenIds[1]);
            nft.burn(u.tokenIds[2]);
        }

        uint256 tokenId = 0;
        if (success) {
            tokenId = nft.mint(u.user, u.targetFeatureNames, u.targetFeatureValues);
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
