pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/INFTStorage.sol";
import "../lib/SignerRecover.sol";

contract NFTFactory is Ownable, INFTFactory, SignerRecover, Initializable {
    using SafeMath for uint256;

    address public DRACE;
    address payable public feeTo;

    event NewBox(address owner, uint256 boxId);
    event OpenBox(address owner, uint256 boxId, uint256 tokenId);
    event UpgradeToken(
        address owner,
        uint256[3] oldTokenId,
        bool upgradeStatus,
        bool useCharm,
        uint256 tokenId
    );
    event BoxRewardUpdated(address addr, uint256 reward);

    //commit reveal needs 2 steps, the reveal step needs to pay fee by bot, this fee is to compensate for bots
    uint256 public SETTLE_FEE = 0.005 ether;
    address payable public SETTLE_FEE_RECEIVER;
    address public masterChef;
    uint256 public boxDiscountPercent = 70;

    mapping(address => bool) public mappingApprover;
    mapping(address => uint256) public boxRewards;

    IDeathRoadNFT public nft;

    constructor() {}

    function initialize(
        address _nft,
        address DRACE_token,
        address payable _feeTo,
        address _notaryHook,
        address _nftStorageHook,
        address _masterChef
    ) external initializer {
        nft = IDeathRoadNFT(_nft);
        DRACE = DRACE_token;
        feeTo = _feeTo;
        notaryHook = INotaryNFT(_notaryHook);
        masterChef = _masterChef;
        nftStorageHook = INFTStorage(_nftStorageHook);
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

    function setBoxDiscountPercent(uint256 _discount) external onlyOwner {
        boxDiscountPercent = _discount;
    }

    function _buyBox(bytes memory _box, bytes memory _pack)
        internal
        returns (uint256)
    {
        uint256 boxId = nft.buyBox(msg.sender, _box, _pack);
        emit NewBox(msg.sender, boxId);
        return boxId;
    }

    // function buyBox(
    //     bytes memory _box,
    //     bytes memory _pack,
    //     uint256 _price,
    //     uint256 _expiryTime,
    //     bytes32 r,
    //     bytes32 s,
    //     uint8 v
    // ) external {
    //     require(block.timestamp <= _expiryTime, "Expired");
    //     bytes32 message = keccak256(
    //         abi.encode("buyBox", msg.sender, _box, _pack, _price, _expiryTime)
    //     );
    //     require(verifySignature(r, s, v, message), "buyBox: Signature invalid");
    //     IERC20 erc20 = IERC20(DRACE);
    //     erc20.transferFrom(msg.sender, feeTo, _price);
    //     _buyBox(_box, _pack);
    // }

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

    mapping(bytes32 => OpenBoxInfo) public _openBoxInfo;
    mapping(address => bytes32[]) public allOpenBoxes;
    mapping(uint256 => bool) public commitedBoxes;
    bytes32[] public allBoxCommitments;
    event CommitOpenBox(address owner, uint256 boxCount, bytes32 commitment);

    function getAllBoxCommitments() external view returns (bytes32[] memory) {
        return allBoxCommitments;
    }

    function openBoxInfo(bytes32 _comm)
        external
        view
        override
        returns (OpenBoxInfo memory)
    {
        return _openBoxInfo[_comm];
    }

    // function commitOpenBox(
    //     uint256 boxId,
    //     bytes[] memory _featureNames, //all have same set of feature sames
    //     bytes[][] memory _featureValuesSet,
    //     bytes32 _commitment,
    //     uint256 _expiryTime,
    //     bytes32 r,
    //     bytes32 s,
    //     uint8 v
    // ) public payable onlyBoxOwner(boxId) boxNotOpen(boxId) {
    //     require(msg.value == SETTLE_FEE, "commitOpenBox: must pay settle fee");
    //     SETTLE_FEE_RECEIVER.transfer(msg.value);
    //     require(!commitedBoxes[boxId], "commitOpenBox: box already commited");
    //     commitedBoxes[boxId] = true;
    //     allBoxCommitments.push(_commitment);
    //     require(
    //         block.timestamp <= _expiryTime,
    //         "commitOpenBox: commitment expired"
    //     );
    //     require(
    //         _openBoxInfo[_commitment].user == address(0),
    //         "commitOpenBox:commitment overlap"
    //     );

    //     require(
    //         _featureNames.length == _featureValuesSet[0].length,
    //         "commitOpenBox:invalid input length"
    //     );

    //     bytes32 message = keccak256(
    //         abi.encode(
    //             "commitOpenBox",
    //             msg.sender,
    //             boxId,
    //             _featureNames,
    //             _featureValuesSet,
    //             _commitment,
    //             _expiryTime
    //         )
    //     );
    //     require(verifySignature(r, s, v, message), "Signature invalid");

    //     OpenBoxInfo storage info = _openBoxInfo[_commitment];

    //     info.user = msg.sender;
    //     info.boxId = boxId;
    //     info.featureNames = _featureNames;
    //     info.featureValuesSet = _featureValuesSet;
    //     info.previousBlockHash = blockhash(block.number - 1);
    //     allOpenBoxes[msg.sender].push(_commitment);

    //     emit CommitOpenBox(msg.sender, boxId, _commitment);
    // }

    function getLatestTokenMinted(address _addr)
        external
        view
        returns (uint256)
    {
        return nft.latestTokenMinted(_addr);
    }

    function updateFeature(
        uint256 tokenId,
        bytes memory featureName,
        bytes memory featureValue,
        uint256 _draceFee,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external {
        require(
            nft.ownerOf(tokenId) == msg.sender,
            "updateFeature: only token owner"
        );
        require(block.timestamp <= _expiryTime, "buyAndCommitOpenBox:Expired");
        IERC20 erc20 = IERC20(DRACE);
        if (_draceFee > 0) {
            erc20.transferFrom(msg.sender, feeTo, _draceFee);
        }
        bytes32 message = keccak256(
            abi.encode(
                "updateFeature",
                msg.sender,
                tokenId,
                featureName,
                featureValue,
                _draceFee,
                _expiryTime
            )
        );
        require(
            verifySignature(r, s, v, message),
            "updateFeature: Signature invalid"
        );

        nft.updateFeature(msg.sender, tokenId, featureName, featureValue);
    }

    INFTStorage public nftStorageHook;

    function setNFTStorage(address _storage) external onlyOwner {
        nftStorageHook = INFTStorage(_storage);
    }

    function buyAndCommitOpenBox(
        bytes memory _box,
        bytes memory _pack,
        uint256 _numBox,
        uint256 _price,
        uint16[] memory _featureValueIndexesSet,
        bool _useBoxReward,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) external payable {
        require(msg.value == SETTLE_FEE, "commitOpenBox: must pay settle fee");
        SETTLE_FEE_RECEIVER.transfer(msg.value);

        //verify signature
        require(block.timestamp <= _expiryTime, "buyAndCommitOpenBox:Expired");
        for(uint256 i = 0; i < _featureValueIndexesSet.length; i++) {
            require(_featureValueIndexesSet[i] < nftStorageHook.getSetLength(), "buyAndCommitOpenBox: _featureValueIndexesSet out of rage");
        }
        
        bytes32 message = keccak256(
            abi.encode(
                "buyAndCommitOpenBox",
                msg.sender,
                _box,
                _pack,
                _numBox,
                _price,
                _featureValueIndexesSet,
                _useBoxReward,
                _commitment,
                _expiryTime
            )
        );
        require(
            verifySignature(r, s, v, message),
            "buyAndCommitOpenBox: Signature invalid"
        );

        transferBoxFee(_numBox.mul(_price), _useBoxReward);
        uint256 boxId;
        for (uint256 i = 0; i < _numBox; i++) {
            boxId = _buyBox(_box, _pack);
            commitedBoxes[boxId] = true;
        }

        //commit open box
        allBoxCommitments.push(_commitment);
        require(
            _openBoxInfo[_commitment].user == address(0),
            "buyAndCommitOpenBox:commitment overlap"
        );

        // require(
        //     _featureNameIndex.length == _featureValueIndexesSet[0].length,
        //     "buyAndCommitOpenBox:invalid input length"
        // );

        OpenBoxInfo storage info = _openBoxInfo[_commitment];

        info.user = msg.sender;
        info.boxIdFrom = boxId.add(1).sub(_numBox);
        info.boxCount = _numBox;
        info.featureValuesSet = _featureValueIndexesSet;
        info.previousBlockHash = blockhash(block.number - 1);
        allOpenBoxes[msg.sender].push(_commitment);

        emit CommitOpenBox(msg.sender, _numBox, _commitment);
    }

    function transferBoxFee(uint256 _price, bool _useBoxReward) internal {
        IERC20 erc20 = IERC20(DRACE);
        if (!_useBoxReward) {
            erc20.transferFrom(msg.sender, feeTo, _price);
        } else {
            uint256 boxRewardSpent = _price.mul(boxDiscountPercent).div(100);
            boxRewards[msg.sender] = boxRewards[msg.sender].sub(boxRewardSpent);
            erc20.transferFrom(msg.sender, feeTo, _price.sub(boxRewardSpent));
        }
    }

    //in case server lose secret, it basically revoke box for user to open again
    function revokeBoxId(uint256 boxId) external onlyOwner {
        commitedBoxes[boxId] = false;
    }

    //client compute result index off-chain, the function will verify it
    function settleOpenBox(bytes32 secret) public {
        bytes32 commitment = keccak256(abi.encode(secret));
        OpenBoxInfo storage info = _openBoxInfo[commitment];
        require(info.user != address(0), "settleOpenBox: commitment not exist");
        require(
            commitedBoxes[info.boxIdFrom],
            "settleOpenBox: box must be committed"
        );
        require(!info.settled, "settleOpenBox: already settled");
        info.settled = true;
        info.openBoxStatus = true;
        uint256[] memory resultIndexes = notaryHook.getOpenBoxResult(
            secret,
            address(this)
        );

        //mint
        for (uint256 i = 0; i < info.boxCount; i++) {
            (bytes[] memory _featureNames, bytes[] memory _featureValues) = nftStorageHook.getFeaturesByIndex(resultIndexes[i]);
            uint256 tokenId = nft.mint(
                info.user,
                _featureNames,
                _featureValues
            );

            nft.setBoxOpen(info.boxIdFrom + i, true);

            emit OpenBox(info.user, info.boxIdFrom + i, tokenId);
        }
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
        override
        returns (bytes[] memory _featureNames, bytes[] memory)
    {
        return nft.getTokenFeatures(tokenId);
    }

    function existTokenFeatures(uint256 tokenId)
        public
        view
        override
        returns (bool)
    {
        return nft.existTokenFeatures(tokenId);
    }

    mapping(bytes32 => UpgradeInfo) public _upgradesInfo;
    mapping(address => bytes32[]) public allUpgrades;
    bytes32[] public allUpgradeCommitments;
    event CommitUpgradeFeature(address owner, bytes32 commitment);

    function getAllUpgradeCommitments()
        external
        view
        returns (bytes32[] memory)
    {
        return allUpgradeCommitments;
    }

    function upgradesInfo(bytes32 _comm)
        external
        view
        override
        returns (UpgradeInfo memory)
    {
        return _upgradesInfo[_comm];
    }

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
        bytes[][] memory _featureValuesSet,
        uint256 _failureRate,
        bool _useCharm,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable {
        require(
            msg.value == SETTLE_FEE,
            "commitUpgradeFeatures: must pay settle fee"
        );
        require(
            _featureNames.length == _featureValuesSet[0].length,
            "commitUpgradeFeatures:invalid input length"
        );
        SETTLE_FEE_RECEIVER.transfer(msg.value);
        require(
            block.timestamp <= _expiryTime,
            "commitUpgradeFeatures: commitment expired"
        );
        require(
            _upgradesInfo[_commitment].user == address(0),
            "commitment overlap"
        );
        allUpgradeCommitments.push(_commitment);
        if (_useCharm) {
            require(
                nft.mappingLuckyCharm(msg.sender) > 0,
                "commitUpgradeFeatures: you need to buy charm"
            );
        }
        //verify infor
        bytes32 message = keccak256(
            abi.encode(
                "commitUpgradeFeatures",
                msg.sender,
                _tokenIds,
                _featureNames,
                _featureValuesSet,
                _failureRate,
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

        _upgradesInfo[_commitment] = UpgradeInfo({
            user: msg.sender,
            useCharm: _useCharm,
            failureRate: _failureRate,
            upgradeStatus: false,
            settled: false,
            tokenIds: _tokenIds,
            targetFeatureNames: _featureNames,
            targetFeatureValuesSet: _featureValuesSet,
            previousBlockHash: blockhash(block.number - 1)
        });
        emit CommitUpgradeFeature(msg.sender, _commitment);
    }

    function settleUpgradeFeatures(bytes32 secret) public {
        bytes32 commitment = keccak256(abi.encode(secret));
        require(
            _upgradesInfo[commitment].user != address(0),
            "settleUpgradeFeatures: commitment not exist"
        );
        require(
            !_upgradesInfo[commitment].settled,
            "settleUpgradeFeatures: updated already settled"
        );

        (bool success, uint256 resultIndex) = notaryHook.getUpgradeResult(
            secret,
            address(this)
        );

        UpgradeInfo storage u = _upgradesInfo[commitment];

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
            for (uint256 i = 0; i < u.tokenIds.length; i++) {
                //burn NFTs
                nft.burn(u.tokenIds[i]);
            }
        }

        uint256 tokenId = 0;
        if (success) {
            tokenId = nft.mint(
                u.user,
                u.targetFeatureNames,
                u.targetFeatureValuesSet[resultIndex]
            );
        }
        u.upgradeStatus = success;
        u.settled = true;

        emit UpgradeToken(u.user, u.tokenIds, success, u.useCharm, tokenId);
    }

    function settleAllRemainingCommitments(
        bytes32[] memory _boxCommitments,
        bytes32[] memory _upgradeCommitments
    ) public {
        for (uint256 i = 0; i < _boxCommitments.length; i++) {
            settleOpenBox(_boxCommitments[i]);
        }

        for (uint256 i = 0; i < _upgradeCommitments.length; i++) {
            settleUpgradeFeatures(_upgradeCommitments[i]);
        }
    }

    INotaryNFT public notaryHook;

    function setNotaryHook(address _notaryHook) external onlyOwner {
        notaryHook = INotaryNFT(_notaryHook);
    }

    function setMasterChef(address _masterChef) external onlyOwner {
        masterChef = _masterChef;
    }

    function addBoxReward(address addr, uint256 reward) external override {
        require(
            msg.sender == masterChef,
            "only masterchef can update box reward"
        );
        boxRewards[addr] = boxRewards[addr].add(reward);
        emit BoxRewardUpdated(addr, reward);
    }
}
