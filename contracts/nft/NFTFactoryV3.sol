pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../interfaces/INotaryNFT.sol";
import "../interfaces/IxDraceDistributor.sol";
import "../interfaces/IDeathRoadNFT.sol";
import "../interfaces/INFTFactoryV2.sol";
import "../interfaces/INFTFactory.sol";
import "../interfaces/INFTStorage.sol";
import "../interfaces/IMint.sol";
import "../lib/SignerRecover.sol";

contract NFTFactoryV3 is Ownable, INFTFactoryV2, SignerRecover, Initializable {
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
    event SetMasterChef(address addr, bool val);

    //commit reveal needs 2 steps, the reveal step needs to pay fee by bot, this fee is to compensate for bots
    uint256 public SETTLE_FEE = 0.01 ether;
    address payable public SETTLE_FEE_RECEIVER;
    mapping(address => bool) public masterChefs;
    uint256 public boxDiscountPercent = 70;

    mapping(address => bool) public mappingApprover;

    IDeathRoadNFT public nft;

    constructor() {}

    function initialize(
        address _nft,
        address DRACE_token,
        address payable _feeTo,
        address _notaryHook,
        address _nftStorageHook,
        address _masterChef,
        address _v,
        address _xDrace
    ) external initializer {
        nft = IDeathRoadNFT(_nft);
        DRACE = DRACE_token;
        feeTo = _feeTo;
        notaryHook = INotaryNFT(_notaryHook);
        masterChefs[_masterChef] = true;
        nftStorageHook = INFTStorage(_nftStorageHook);
        xDraceVesting = IxDraceDistributor(_v);
        xDrace = IMint(_xDrace);
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

    function addBox(bytes memory _box) public onlyOwner {
        nft.addBox(_box);
    }

    function addBoxes(bytes[] memory _boxes) public onlyOwner {
        nft.addBoxes(_boxes);
    }

    function addPack(bytes memory _pack) public onlyOwner {
        nft.addPack(_pack);
    }

    function addPacks(bytes[] memory _packs) public onlyOwner {
        nft.addPacks(_packs);
    }

    //    function addFeature(bytes memory _box, bytes memory _feature)
    //        public
    //        onlyOwner
    //    {
    //        nft.addFeature(_box, _feature);
    //    }

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
        bool _useXdrace,
        uint256 _expiryTime,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public {
        require(block.timestamp <= _expiryTime, "Expired");
        bytes32 message = keccak256(
            abi.encode("buyCharm", msg.sender, _price, _useXdrace, _expiryTime)
        );
        require(verifySignature(r, s, v, message), "Signature invalid");
        transferBoxFee(_price, _useXdrace);
        nft.buyCharm(msg.sender);
    }

    mapping(bytes32 => OpenBoxInfo) public _openBoxInfo;
    mapping(address => bytes32[]) public allOpenBoxes;
    mapping(uint256 => bool) public committedBoxes;
    bytes32[] public allBoxCommitments;
    event CommitOpenBox(
        address owner,
        bytes boxType,
        bytes packType,
        uint256 boxCount,
        bytes32 commitment
    );

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
        require(
            msg.value == SETTLE_FEE * _numBox,
            "commitOpenBox: must pay settle fee"
        );
        SETTLE_FEE_RECEIVER.transfer(msg.value);

        //verify signature
        require(block.timestamp <= _expiryTime, "buyAndCommitOpenBox:Expired");
        for (uint256 i = 0; i < _featureValueIndexesSet.length; i++) {
            require(
                _featureValueIndexesSet[i] < nftStorageHook.getSetLength(),
                "buyAndCommitOpenBox: _featureValueIndexesSet out of rage"
            );
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
            committedBoxes[boxId] = true;
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

        emit CommitOpenBox(msg.sender, _box, _pack, _numBox, _commitment);
    }

    function transferBoxFee(uint256 _price, bool _useBoxReward) internal {
        IERC20 erc20 = IERC20(DRACE);
        if (!_useBoxReward) {
            erc20.transferFrom(msg.sender, feeTo, _price);
        } else {
            uint256 boxRewardSpent = _price.mul(boxDiscountPercent).div(100);
            ERC20Burnable(address(xDrace)).burnFrom(msg.sender, boxRewardSpent);
            erc20.transferFrom(msg.sender, feeTo, _price.sub(boxRewardSpent));
        }
    }

    //in case server lose secret, it basically revoke box for user to open again
    function revokeBoxId(uint256 boxId) external onlyOwner {
        committedBoxes[boxId] = false;
    }

    //client compute result index off-chain, the function will verify it
    function settleOpenBox(bytes32 secret) public {
        bytes32 commitment = keccak256(abi.encode(secret));
        OpenBoxInfo storage info = _openBoxInfo[commitment];
        require(info.user != address(0), "settleOpenBox: commitment not exist");
        require(
            committedBoxes[info.boxIdFrom],
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
            (
                bytes[] memory _featureNames,
                bytes[] memory _featureValues
            ) = nftStorageHook.getFeaturesByIndex(resultIndexes[i]);
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
    mapping(bytes32 => UpgradeInfoV2) public _upgradesInfoV2;
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

    function upgradesInfoV2(bytes32 _comm)
        external
        view
        override
        returns (UpgradeInfoV2 memory)
    {
        return _upgradesInfoV2[_comm];
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
        uint256[] memory _featureValueIndexesSet,
        uint256 _failureRate,
        bool _useCharm,
        uint256 _upgradeFee,
        bool _useXDrace,
        bytes32 _commitment,
        uint256 _expiryTime,
        bytes32[2] memory rs,
        uint8 v
    ) public payable {
        require(
            msg.value == SETTLE_FEE,
            "commitUpgradeFeatures: must pay settle fee"
        );

        SETTLE_FEE_RECEIVER.transfer(msg.value);
        require(
            block.timestamp <= _expiryTime,
            "commitUpgradeFeatures: commitment expired"
        );
        require(
            _upgradesInfoV2[_commitment].user == address(0),
            "commitment overlap"
        );

        for (uint256 i = 0; i < _featureValueIndexesSet.length; i++) {
            require(
                _featureValueIndexesSet[i] < nftStorageHook.getSetLength(),
                "buyAndCommitOpenBox: _featureValueIndexesSet out of rage"
            );
        }

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
                _featureValueIndexesSet,
                _failureRate,
                _useCharm,
                _upgradeFee,
                _useXDrace,
                _commitment,
                _expiryTime
            )
        );
        require(
            verifySignature(rs[0], rs[1], v, message),
            "commitUpgradeFeatures:Signature invalid"
        );

        transferBoxFee(_upgradeFee, _useXDrace);

        //need to lock token Ids here
        transferTokensIn(_tokenIds);

        pushUpgradeInfo(
            _commitment,
            _useCharm,
            _failureRate,
            _tokenIds,
            _featureValueIndexesSet
        );

        allUpgrades[msg.sender].push(_commitment);
    }

    function pushUpgradeInfo(
        bytes32 _commitment,
        bool _useCharm,
        uint256 _failureRate,
        uint256[3] memory _tokenIds,
        uint256[] memory _featureValueIndexesSet
    ) internal {
        _upgradesInfoV2[_commitment] = UpgradeInfoV2({
            user: msg.sender,
            useCharm: _useCharm,
            failureRate: _failureRate,
            upgradeStatus: false,
            settled: false,
            tokenIds: _tokenIds,
            featureValueIndexesSet: _featureValueIndexesSet,
            previousBlockHash: blockhash(block.number - 1)
        });
        emit CommitUpgradeFeature(msg.sender, _commitment);
    }

    function transferTokensIn(uint256[3] memory _tokenIds) internal {
        nft.transferFrom(msg.sender, address(this), _tokenIds[0]);
        nft.transferFrom(msg.sender, address(this), _tokenIds[1]);
        nft.transferFrom(msg.sender, address(this), _tokenIds[2]);
    }

    function settleUpgradeFeatures(bytes32 secret) public {
        bytes32 commitment = keccak256(abi.encode(secret));
        require(
            _upgradesInfoV2[commitment].user != address(0),
            "settleUpgradeFeatures: commitment not exist"
        );
        require(
            !_upgradesInfoV2[commitment].settled,
            "settleUpgradeFeatures: updated already settled"
        );

        (bool success, uint256 resultIndex) = notaryHook.getUpgradeResult(
            secret,
            address(this)
        );

        UpgradeInfoV2 storage u = _upgradesInfoV2[commitment];

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
            (
                bytes[] memory _featureNames,
                bytes[] memory _featureValues
            ) = nftStorageHook.getFeaturesByIndex(resultIndex);

            tokenId = nft.mint(u.user, _featureNames, _featureValues);
            if (u.useCharm) {
                nft.decreaseCharm(u.user);
            }
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
        masterChefs[_masterChef] = true;
        emit SetMasterChef(_masterChef, true);
    }

    function removeMasterChef(address _masterChef) external onlyOwner {
        masterChefs[_masterChef] = false;
        emit SetMasterChef(_masterChef, false);
    }

    INFTFactory public oldFactory =
        INFTFactory(0x9accf295895595D694b5D9E781082686dfa2801A);
    IMint public xDrace;

    function setOldFactory(address _old) external onlyOwner {
        oldFactory = INFTFactory(_old);
    }

    INFTFactoryV2 public factoryV2 =
        INFTFactoryV2(0x817e1F3C6987E4185E75db630591244b7B1a17d1);

    function setFactoryV2(address _v2) external onlyOwner {
        factoryV2 = INFTFactoryV2(_v2);
    }

    function setXDRACE(address _xdrace) external onlyOwner {
        xDrace = IMint(_xdrace);
    }

    function setXDraceVesting(address _v) external onlyOwner {
        xDraceVesting = IxDraceDistributor(_v);
    }

    mapping(address => bool) public override alreadyMinted;
    IxDraceDistributor public xDraceVesting;

    function addBoxReward(address addr, uint256 reward) external override {
        require(
            masterChefs[msg.sender],
            "only masterchef can update box reward"
        );

        uint256 _toMint = reward;
        if (!alreadyMinted[addr] && factoryV2.alreadyMinted(addr)) {
            _toMint = oldFactory.boxRewards(addr).add(_toMint);
            alreadyMinted[addr] = true;
        }

        xDrace.mint(addr, _toMint);
    }

    function boxRewards(address _addr)
        external
        view
        override
        returns (uint256)
    {
        if (!alreadyMinted[_addr]) {
            return oldFactory.boxRewards(_addr);
        }
        return IERC20(address(xDrace)).balanceOf(_addr);
    }

    function getXDraceLockInfo(address _addr)
        external
        view
        returns (uint256, uint256)
    {
        return xDraceVesting.getLockedInfo(_addr);
    }

    function decreaseBoxReward(address addr, uint256 reduced)
        external
        override
    {
        //do nothing
    }
}
