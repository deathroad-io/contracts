pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDeathRoadNFT is IERC721 {
    struct Box {
        bool isOpen;
        address owner;
        bytes32 boxType; // car, weapon, other,....
        bytes32 packType; // iron, bronze, silver, gold, platinum, diamond
    }

    function getFeatures(uint256 tokenId)
        external
        view
        returns (bytes32[] memory, bytes32[] memory);

    function existFeatures(uint256 tokenId) external view returns (bool);

    struct FeatureValue {
        string dataType;
        bytes encodedValue;
    }
    struct UpgradeInfo {
        address user;
        bool useCharm;
        bool settled;
        bool upgradeStatus;
        uint256 successRate; //percentX10
        uint256[3] tokenIds;
        bytes[] targetFeatureNames;
        bytes[] targetFeatureValues;
        bytes32 previousBlockHash;
    }

    struct OpenBoxInfo {
        address user;
        uint256 boxId;
        bool settled;
        bool openBoxStatus;
        mapping(uint256 => uint256[2]) successRateRanges;
        uint256 totalRate;
        bytes[] featureNames;
        bytes[][] featureValuesSet;
        bytes32 previousBlockHash;
    }

    struct OpenBoxBasicInfo {
        address user;
        uint256 boxId;
        uint256 totalRate;
        bytes[] featureNames;
        bytes[][] featureValuesSet;
        bytes32 previousBlockHash;
    }

    function upgradesInfo(bytes32) external view returns (UpgradeInfo memory);

    function allUpgrades(address) external view returns (bytes32[] memory);

    function getBasicOpenBoxInfo(bytes32 commitment)
        external
        view
        returns (
            OpenBoxBasicInfo memory
        );
    function getSuccessRateRange(bytes32 commitment, uint256 _index) external view returns (uint256[2] memory);
}
