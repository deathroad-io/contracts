pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INFTFactory {
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

    struct OpenBoxInfo {
        address user;
        uint256 boxIdFrom;
        uint256 boxIdCount;
        bool settled;
        bool openBoxStatus;
        bytes[] featureNames;
        bytes[][] featureValuesSet;
        bytes32 previousBlockHash;
    }

    function upgradesInfo(bytes32) external view returns (UpgradeInfo memory);

    function openBoxInfo(bytes32) external view returns (OpenBoxInfo memory);

    function addBoxReward(address addr, uint256 reward) external;
}
