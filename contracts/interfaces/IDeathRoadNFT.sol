pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IDeathRoadNFT is IERC721 {
    struct Box {
        bool isOpen;
        address owner;
        bytes box; // car, gun, rocket, other,...
        bytes pack; // 1star, 2star, 3star, 4star, 5star, legend,...
    }

    function getBoxes() external view returns (bytes[] memory);

    function getPacks() external view returns (bytes[] memory);

    function addBox(bytes memory _box) external;
    function addBoxes(bytes[] memory _boxes) external;

    function addPack(bytes memory _pack) external;
    function addPacks(bytes[] memory _packs) external;

//    function addFeature(bytes memory _box, bytes memory _feature) external;

    function buyBox(
        address _recipient,
        bytes memory _box,
        bytes memory _pack
    ) external returns (uint256);

    function buyCharm(address _recipient) external;

    function isBoxOwner(address _addr, uint256 _boxId)
        external
        view
        returns (bool);

    function isBoxOpen(uint256 _boxId) external view returns (bool);

    function mint(
        address _recipient,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) external returns (uint256 _tokenId);

    function setBoxOpen(uint256 _boxId, bool _val) external;

    function getTokenFeatures(uint256 tokenId)
        external
        view
        returns (bytes[] memory _featureNames, bytes[] memory);

    function existTokenFeatures(uint256 tokenId) external view returns (bool);
    function mappingLuckyCharm(address) external view returns (uint256);
    function burn(uint256 tokenId) external;
    function decreaseCharm(address _addr) external;
    function latestTokenMinted(address _addr) external view returns (uint256);

    function updateFeature(address _owner, uint256 tokenId, bytes memory featureName, bytes memory featureValue) external;
}
