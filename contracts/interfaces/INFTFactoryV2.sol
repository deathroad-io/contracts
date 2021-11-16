pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTFactoryV2 {
    function getTokenFeatures(uint256 tokenId)
        external
        view
        returns (bytes[] memory, bytes[] memory);

    function existTokenFeatures(uint256 tokenId) external view returns (bool);

    struct UpgradeInfo {
        address user;
        bool useCharm;
        bool settled;
        bool upgradeStatus;
        uint256 failureRate; //percentX10
        uint256[3] tokenIds;
        bytes[] targetFeatureNames;
        bytes[][] targetFeatureValuesSet;
        bytes32 previousBlockHash;
    }

    struct UpgradeInfoV2 {
        address user;
        bool useCharm;
        bool settled;
        bool upgradeStatus;
        uint256 failureRate; //percentX10
        uint256[3] tokenIds;
        uint256[] featureValueIndexesSet;
        bytes32 previousBlockHash;
    }

    struct OpenBoxInfo {
        address user;
        uint256 boxIdFrom;
        uint256 boxCount;
        bool settled;
        bool openBoxStatus;
        uint16[] featureValuesSet;
        bytes32 previousBlockHash;
        uint256 blockNumber;
    }

    function upgradesInfo(bytes32) external view returns (UpgradeInfo memory);
    function upgradesInfoV2(bytes32) external view returns (UpgradeInfoV2 memory);

    function openBoxInfo(bytes32) external view returns (OpenBoxInfo memory);

    function addBoxReward(address addr, uint256 reward) external;

    function decreaseBoxReward(address addr, uint256 reduced) external;

    function boxRewards(address) external view returns (uint256);
    function alreadyMinted(address) external view returns (bool);
}
