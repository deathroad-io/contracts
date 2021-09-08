pragma solidity ^0.8.0;

interface INFTStorage {
    function addFeatures(
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) external;

    function addFeaturesMany(
        bytes[][] memory _featureNamesSet,
        bytes[][] memory _featureValuesSet
    ) external;

    function getAllFeatures()
        external
        view
        returns (
            bytes[][] memory _featureNames,
            bytes[][] memory _featureValues
        );

    function getSetLength() external view returns (uint256);

    function getFeaturesByIndex(uint256 index)
        external
        view
        returns (bytes[] memory _featureNames, bytes[] memory _featureValues);
}
